-- Conexão: ban, whitelist e vínculo license ↔ discord.
-- Spec: docs/sp-capital-rp/specs/spc_core.md §3
local DB = SPC.DB

-- license → { account, expiresAt } aguardando o playerJoining (troca do source temporário)
local pending = {}
local PENDING_TTL_MS = 120000

local MESSAGES = {
    no_license = 'Não foi possível identificar sua licença Rockstar. Reinicie o FiveM.',
    no_discord = 'Abra o Discord (aplicativo) antes do FiveM para entrar na SP Capital.',
    no_account = 'Você ainda não tem whitelist. Faça a sua no nosso Discord.',
    pending = 'Sua whitelist está em análise. Acompanhe pelo Discord.',
    rejected = 'Sua whitelist foi reprovada. Você pode tentar novamente pelo Discord após o prazo.',
    suspended = 'Sua conta está suspensa. Abra um ticket no Discord.',
    mismatch = 'Esta licença ou conta Discord já está vinculada a outra conta. Abra um ticket no Discord.',
    error = 'Erro ao verificar sua conta. Tente novamente em instantes.',
}

local function identifiersOf(src)
    local ids = {}
    for _, t in ipairs({ 'license', 'license2', 'discord', 'fivem', 'steam' }) do
        ids[t] = GetPlayerIdentifierByType(src, t)
    end
    return ids
end

local function findBan(identifierList, accountId)
    local params = {}
    for _, v in ipairs(identifierList) do params[#params + 1] = v end
    local accountClause = ''
    if accountId then
        accountClause = ' OR b.account_id = ?'
        params[#params + 1] = accountId
    end
    return DB.single(([[
        SELECT b.id, b.reason, DATE_FORMAT(b.expires_at, '%%d/%%m/%%Y %%H:%%i') AS expires
        FROM bans b
        WHERE b.revoked_at IS NULL AND (b.expires_at IS NULL OR b.expires_at > NOW())
          AND (b.id IN (SELECT ban_id FROM ban_identifiers WHERE identifier IN (%s))%s)
        ORDER BY b.expires_at IS NULL DESC, b.expires_at DESC
        LIMIT 1]]):format(DB.placeholders(#identifierList), accountClause), params)
end

local function banMessage(ban)
    return ('Você está banido da SP Capital.\nMotivo: %s\nExpira: %s\nID do ban: #%d (use no ticket de revisão)')
        :format(ban.reason, ban.expires or 'permanente', DB.int(ban.id))
end

--- Verifica a conta. Retorna account (linha) ou nil, chave de mensagem / ban.
function SPC.checkAccount(ids)
    local discordId = ids.discord and ids.discord:gsub('^discord:', '') or nil
    local identifierList = {}
    for _, v in pairs(ids) do identifierList[#identifierList + 1] = v end

    local ban = findBan(identifierList, nil)
    if ban then return nil, 'ban', ban end

    local rows = DB.query([[
        SELECT a.id, a.discord_id, a.license, a.whitelist_status, a.char_slots, s.role AS staff_role, s.active AS staff_active
        FROM accounts a LEFT JOIN staff s ON s.account_id = a.id
        WHERE a.license = ? OR a.discord_id = ?]], { ids.license, discordId })
    if not rows then return nil, 'error' end
    if #rows == 0 then return nil, 'no_account' end
    if #rows > 1 then return nil, 'mismatch' end

    local acc = rows[1]
    if acc.discord_id ~= discordId or (acc.license and acc.license ~= ids.license) then return nil, 'mismatch' end
    if acc.whitelist_status ~= 'approved' then return nil, acc.whitelist_status end

    ban = findBan(identifierList, DB.int(acc.id))
    if ban then return nil, 'ban', ban end
    return acc
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Verificando sua conta na SP Capital...')

    local ids = identifiersOf(src)
    if not ids.license then return deferrals.done(MESSAGES.no_license) end
    if not ids.discord then return deferrals.done(MESSAGES.no_discord) end

    local ok, acc, reason, ban = pcall(SPC.checkAccount, ids)
    if not ok then
        SPC.Log('connection', 'error', { license = ids.license, error = tostring(acc) }, 'warn')
        return deferrals.done(MESSAGES.error)
    end
    if not acc then
        SPC.Log('connection', 'refused', { license = ids.license, discord = ids.discord, reason = reason,
            banId = ban and DB.int(ban.id) or nil })
        return deferrals.done(reason == 'ban' and banMessage(ban) or MESSAGES[reason] or MESSAGES.error)
    end

    local accountId = DB.int(acc.id)
    DB.update([[
        UPDATE accounts SET license = COALESCE(license, ?), license2 = ?, fivem_id = ?, steam_id = ?, last_login_at = NOW()
        WHERE id = ?]], { ids.license, ids.license2, ids.fivem, ids.steam, accountId })

    pending[ids.license] = {
        expiresAt = GetGameTimer() + PENDING_TTL_MS,
        session = {
            accountId = accountId, license = ids.license, discordId = acc.discord_id,
            charSlots = DB.int(acc.char_slots),
            staffRole = (DB.int(acc.staff_active) == 1) and acc.staff_role or nil,
        },
    }
    SPC.Log('connection', 'accepted', { license = ids.license, accountId = accountId })
    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    local p = license and pending[license]
    if not p or p.expiresAt < GetGameTimer() then
        pending[license or ''] = nil
        DropPlayer(src, MESSAGES.error)
        return
    end
    pending[license] = nil
    local session = p.session
    session.source = src
    session.joinedAt = os.time()
    SPC.Players.add(session)
    TriggerEvent('spc_core:server:playerJoined', src, session.accountId)
end)

-- Limpeza de pendências expiradas (conexões abandonadas durante o carregamento)
CreateThread(function()
    while true do
        Wait(60000)
        local now = GetGameTimer()
        for license, p in pairs(pending) do
            if p.expiresAt < now then pending[license] = nil end
        end
    end
end)
