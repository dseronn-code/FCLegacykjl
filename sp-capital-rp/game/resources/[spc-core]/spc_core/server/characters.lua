-- Personagens: listar, criar e selecionar.
-- Spec: docs/sp-capital-rp/specs/spc_core.md §4
local DB, Identity, Config = SPC.DB, SPC.Identity, SPC.Config

SPC.Characters = {}
local Characters = SPC.Characters

local function decode(v)
    if type(v) == 'string' then
        local ok, res = pcall(json.decode, v)
        return ok and res or nil
    end
    return v
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

function Characters.list(accountId)
    local rows = DB.query([[
        SELECT citizenid, first_name, last_name, DATE_FORMAT(birthdate, '%Y-%m-%d') AS birthdate, gender
        FROM characters WHERE account_id = ? AND deleted_at IS NULL AND ck_at IS NULL ORDER BY id]], { accountId }) or {}
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = { citizenid = r.citizenid, firstName = r.first_name, lastName = r.last_name,
            birthdate = r.birthdate, gender = r.gender }
    end
    return out
end

--- Valida a entrada do cliente. Retorna dados normalizados ou nil, erro.
function Characters.validate(data)
    if type(data) ~= 'table' then return nil, 'invalid_data' end
    local first, e1 = Identity.normalizeName(data.firstName, Config.BlockedNameWords)
    if not first then return nil, e1 end
    local last, e2 = Identity.normalizeName(data.lastName, Config.BlockedNameWords)
    if not last then return nil, e2 end
    local today = os.date('!*t')
    local ok, e3 = Identity.validateBirthdate(data.birthdate, today, Config.MinAge, Config.MaxAge)
    if not ok then return nil, e3 end
    if not Identity.isValidGender(data.gender) then return nil, 'invalid_gender' end
    local nationality = data.nationality or Config.Nationalities[1]
    if not contains(Config.Nationalities, nationality) then return nil, 'invalid_nationality' end
    return { firstName = first, lastName = last, birthdate = data.birthdate, gender = data.gender, nationality = nationality }
end

function Characters.create(session, data)
    local input, err = Characters.validate(data)
    if not input then return false, err end

    local used = DB.int(DB.scalar(
        'SELECT COUNT(*) FROM characters WHERE account_id = ? AND deleted_at IS NULL AND ck_at IS NULL',
        { session.accountId })) or 0
    if used >= (session.charSlots or Config.DefaultCharSlots) then return false, 'no_slots' end

    local rand = math.random
    for _ = 1, 5 do -- novas tentativas em caso de colisão de citizenid/CPF/RG/telefone
        local cid = Identity.citizenId(rand)
        local tx = { legs = { { from = { system = 'MINT_STARTER' }, to = nil, amount = Config.StarterMoney,
            reason = 'starter.grant', ref = { type = 'character', id = cid } } } }
        local ledgerResult

        local committed = DB.transaction(function(query)
            local ins = query([[
                INSERT INTO characters (citizenid, account_id, first_name, last_name, birthdate, gender, nationality, cpf, rg, phone_number)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                { cid, session.accountId, input.firstName, input.lastName, input.birthdate, input.gender,
                  input.nationality, Identity.cpf(rand), Identity.rg(rand), Identity.phone(rand) })
            local charId = DB.int(ins.insertId)

            local bank = query("INSERT INTO bank_accounts (number, owner_type, owner_id, kind) VALUES (?, 'character', ?, 'checking')",
                { 'TMP' .. cid, charId })
            local bankId = DB.int(bank.insertId)
            query("UPDATE bank_accounts SET number = CONCAT('0002-', LPAD(id, 7, '0')) WHERE id = ?", { bankId })

            tx.legs[1].to = { id = bankId }
            local r = SPC.Ledger.executeWith(query, tx, 'system', 'spc_core')
            if not r then return false end
            ledgerResult = r
            return true
        end)

        if committed then
            SPC.Ledger.afterCommit(tx, ledgerResult, 'system', 'spc_core')
            SPC.Log('character', 'created', { src = session.source, accountId = session.accountId, citizenid = cid })
            return true, cid
        end
    end
    return false, 'db_error'
end

function Characters.select(session, citizenid)
    if session.character then return false, 'already_loaded' end
    if type(citizenid) ~= 'string' or not citizenid:match('^SPC[0-9A-Z]+$') then return false, 'invalid_citizenid' end

    local row = DB.single([[
        SELECT c.id, c.citizenid, c.first_name, c.last_name, DATE_FORMAT(c.birthdate, '%Y-%m-%d') AS birthdate, c.gender,
               c.cpf, c.rg, c.phone_number, c.appearance, c.position, c.status, c.is_dead, c.jail_minutes, b.id AS bank_id
        FROM characters c
        LEFT JOIN bank_accounts b ON b.owner_type = 'character' AND b.owner_id = c.id AND b.kind = 'checking'
        WHERE c.citizenid = ? AND c.account_id = ? AND c.deleted_at IS NULL AND c.ck_at IS NULL]],
        { citizenid, session.accountId })
    if not row then return false, 'not_found' end

    local character = {
        id = DB.int(row.id), citizenid = row.citizenid, firstName = row.first_name, lastName = row.last_name,
        birthdate = row.birthdate, gender = row.gender, cpf = row.cpf, rg = row.rg, phone = row.phone_number,
        bankAccountId = DB.int(row.bank_id), status = decode(row.status) or {},
        jailMinutes = DB.int(row.jail_minutes) or 0, isDead = DB.int(row.is_dead) == 1,
        loadedAt = os.time(),
    }
    SPC.Players.setCharacter(session.source, character)

    local state = Player(session.source).state
    state:set('citizenid', character.citizenid, true)
    state:set('name', character.firstName .. ' ' .. character.lastName, true)
    state:set('status', character.status, true)
    state:set('jailMinutes', character.jailMinutes, false)
    state:set('loaded', true, true)

    local pos = decode(row.position) or Config.DefaultSpawn
    TriggerClientEvent('spc_core:client:characterLoaded', session.source, {
        citizenid = character.citizenid, gender = character.gender, position = pos,
        appearance = decode(row.appearance), isDead = character.isDead,
    })
    TriggerEvent('spc_core:server:characterLoaded', session.source, character.citizenid)
    SPC.Log('character', 'selected', { src = session.source, citizenid = character.citizenid })
    return true
end

-- Callbacks do cliente: sempre com sessão válida e rate limit
local function guarded(name, fn)
    lib.callback.register('spc_core:' .. name, function(src, ...)
        local session = SPC.Players.get(src)
        if not session then return { ok = false, error = 'no_session' } end
        if not SPC.allow(src, name) then return { ok = false, error = 'rate_limited' } end
        return fn(session, ...)
    end)
end

guarded('characters:list', function(session)
    return { ok = true, characters = Characters.list(session.accountId) }
end)

guarded('characters:create', function(session, data)
    local ok, res = Characters.create(session, data)
    return ok and { ok = true, citizenid = res } or { ok = false, error = res }
end)

guarded('characters:select', function(session, citizenid)
    local ok, err = Characters.select(session, citizenid)
    return { ok = ok, error = err }
end)
