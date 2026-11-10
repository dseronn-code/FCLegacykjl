-- Integração do spc_admin: permissões, hierarquia, ban por identificadores/tokens, advertências e auditoria.
local results = { passed = 0, failed = 0, failures = {} }
local function it(name, fn)
    local ok, err = pcall(fn)
    if ok then results.passed = results.passed + 1
    else results.failed = results.failed + 1; table.insert(results.failures, name .. ': ' .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or '') .. ' esperado ' .. tostring(b) .. ', obtido ' .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or 'esperado verdadeiro', 2) end end
local DB = SPC.DB
local function lastNotice(src) local n = Fake.notices(src); return n[#n] or '' end

-- Contas: 20 = moderador, 21 = jogador, 22 = admin, 23 = sem staff
DB.update([[INSERT INTO accounts (discord_id, whitelist_status) VALUES ('d20','approved'),('d21','approved'),('d22','approved'),('d23','approved'),('d24','approved')]])
DB.update([[INSERT INTO staff (account_id, role) SELECT id, 'mod' FROM accounts WHERE discord_id = 'd20']])
DB.update([[INSERT INTO staff (account_id, role) SELECT id, 'admin' FROM accounts WHERE discord_id = 'd22']])

local function join(src, n, tokens)
    Fake.identifiers[src] = { license = 'license:l' .. n, discord = 'discord:d' .. n }
    Fake.tokens[src] = tokens or {}
    local done = {}
    Fake.emit('playerConnecting', src, 'J', nil, { defer = function() end, update = function() end, done = function(r) done.reason = r; done.called = true end })
    if done.reason then return done end
    Fake.emit('playerJoining', src)
    return done
end

join(20, 20); join(21, 21, { '3:abcdef' }); join(22, 22); join(23, 23)

it('sessões de staff carregam o papel', function()
    eq(SPC.Players.get(20).staffRole, 'mod'); eq(SPC.Players.get(22).staffRole, 'admin'); eq(SPC.Players.get(21).staffRole, nil)
end)

it('jogador sem staff não pode kickar', function()
    Fake.run(23, 'kick 21 motivo qualquer'); truthy(lastNotice(23):find('permissão'), lastNotice(23))
end)

it('moderador não pode banir por mais de 72 h', function()
    Fake.run(20, 'ban 21 100 RDM na praça'); truthy(lastNotice(20):find('72'), lastNotice(20))
end)

it('moderador não pode banir admin (hierarquia)', function()
    Fake.run(20, 'ban 22 24 teste de hierarquia'); truthy(lastNotice(20):find('superior'), lastNotice(20))
end)

it('ban exige motivo', function()
    Fake.run(20, 'ban 21 24 rdm'); truthy(lastNotice(20):find('motivo'), lastNotice(20))
end)

local banId
it('ban grava identificadores e token, derruba e audita', function()
    local before = #Fake.dropped
    Fake.run(20, 'ban 21 24 RDM na Avenida Paulistana')
    eq(#Fake.dropped, before + 1); eq(Fake.dropped[#Fake.dropped].src, 21)
    banId = DB.int(DB.scalar("SELECT id FROM bans WHERE reason = 'RDM na Avenida Paulistana'"))
    truthy(banId, 'ban gravado')
    local ids = DB.query('SELECT identifier FROM ban_identifiers WHERE ban_id = ? ORDER BY identifier', { banId })
    local set = {}
    for _, r in ipairs(ids) do set[r.identifier] = true end
    truthy(set['license:l21'] and set['discord:d21'] and set['token:3:abcdef'], 'identificadores')
    eq(DB.int(DB.scalar("SELECT COUNT(*) FROM audit_log WHERE action = 'ban'")), 1)
    truthy(DB.scalar('SELECT expires_at FROM bans WHERE id = ?', { banId }), 'temporário tem expiração')
end)

it('ban evasion: outra conta Discord no mesmo PC (token) é recusada', function()
    local d = join(30, 24, { '3:abcdef' })
    truthy(d.reason and d.reason:find('#' .. banId), d.reason)
end)

it('advertência soma pontos ativos', function()
    Fake.run(20, 'warn 23 2 Anti-RP na delegacia')
    eq(DB.int(DB.scalar("SELECT SUM(points) FROM warnings w JOIN accounts a ON a.id = w.account_id WHERE a.discord_id = 'd23'")), 2)
    truthy(lastNotice(23):find('advertência'), lastNotice(23))
end)

it('moderador não pode revogar ban; admin pode', function()
    Fake.run(20, 'unban ' .. banId .. ' revisão aceita'); truthy(lastNotice(20):find('permissão'))
    Fake.run(22, 'unban ' .. banId .. ' revisão aceita')
    truthy(DB.scalar('SELECT revoked_at FROM bans WHERE id = ?', { banId }), 'revogado')
    local d = join(31, 24, { '3:abcdef' }); eq(d.reason, nil, 'entra após revogação')
end)

it('teleporte exige modo staff', function()
    Fake.run(22, 'tp 23'); truthy(lastNotice(22):find('modo staff'), lastNotice(22))
    Fake.run(22, 'staff'); eq(Fake.states[22].staffMode, true)
    Fake.run(22, 'tp 23'); truthy(not lastNotice(22):find('modo staff'))
end)

it('console pode banir permanentemente', function()
    Fake.run(0, 'ban 23 perm Uso de cheat confirmado')
    eq(DB.scalar("SELECT expires_at FROM bans WHERE reason = 'Uso de cheat confirmado'"), nil)
end)

return results
