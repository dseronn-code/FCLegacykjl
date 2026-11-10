-- Integração da Fase 2: spc_needs e spc_bank sobre o spc_core real e MariaDB real.
local results = { passed = 0, failed = 0, failures = {} }
local function it(name, fn)
    local ok, err = pcall(fn)
    if ok then results.passed = results.passed + 1
    else results.failed = results.failed + 1; table.insert(results.failures, name .. ': ' .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or '') .. ' esperado ' .. tostring(b) .. ', obtido ' .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or 'esperado verdadeiro', 2) end end
local DB = SPC.DB
local BRANCH = SPCBank.Config.Branches[1].coords
local function later() Fake.now = Fake.now + 5000 end -- passa o cooldown de 2 s do banco

DB.update("INSERT INTO accounts (discord_id, whitelist_status) VALUES ('d40','approved'),('d41','approved')")

local function enter(src, n, first)
    Fake.identifiers[src] = { license = 'license:l' .. n, discord = 'discord:d' .. n }
    Fake.tokens[src] = {}
    Fake.emit('playerConnecting', src, 'J', nil, { defer = function() end, update = function() end, done = function() end })
    Fake.emit('playerJoining', src)
    local r = Fake.callbacks['spc_core:characters:create'](src, { firstName = first, lastName = 'Souza', birthdate = '1990-05-05', gender = 'f' })
    assert(r.ok, r.error)
    SPC.Limiter:clear(src .. ':')
    assert(Fake.callbacks['spc_core:characters:select'](src, r.citizenid).ok)
    -- o spc_core dispara o evento via TriggerEvent (simulado só como registro); entregamos aos handlers
    Fake.emit('spc_core:server:characterLoaded', 0, src, r.citizenid)
    return r.citizenid
end

local cid40 = enter(40, 40, 'Bruna')
local cid41 = enter(41, 41, 'Carlos')
local acc40 = SPC.Players.get(40).character.bankAccountId
local acc41 = SPC.Players.get(41).character.bankAccountId
local function bal(acc) return DB.int(DB.scalar('SELECT balance FROM bank_accounts WHERE id = ?', { acc })) end

-- Necessidades -------------------------------------------------------------
it('status inicial padrão no carregamento', function()
    eq(Fake.states[40].status.hunger, 100); eq(Fake.states[40].status.thirst, 100); eq(Fake.states[40].status.stress, 0)
end)

it('ciclo do servidor decai fome e sede', function()
    SPCNeeds.tickPlayer(40)
    eq(Fake.states[40].status.hunger, 99.45); eq(Fake.states[40].status.thirst, 99.17)
end)

it('modo staff pausa o decaimento', function()
    Fake.states[41].staffMode = true
    SPCNeeds.tickPlayer(41); eq(Fake.states[41].status.hunger, 100)
    Fake.states[41].staffMode = nil
end)

it('beber água (evento do ox_inventory) aplica o efeito do servidor', function()
    Fake.states[40].status = { hunger = 50, thirst = 20, stress = 30 }
    Fake.emit('ox_inventory:usedItem', 0, 40, 'water', 3)
    eq(Fake.states[40].status.thirst, 55)
    Fake.emit('ox_inventory:usedItem', 0, 40, 'lockpick', 4)
    eq(Fake.states[40].status.thirst, 55, 'item não consumível não altera')
end)

it('fome zerada causa dano no cliente', function()
    Fake.states[40].status = { hunger = 0, thirst = 50 }
    local before = #Fake.clientEvents
    SPCNeeds.tickPlayer(40)
    local found = false
    for i = before + 1, #Fake.clientEvents do
        if Fake.clientEvents[i].name == 'spc_needs:client:starve' then found = true end
    end
    truthy(found, 'evento de dano')
end)

it('status de necessidades persiste no salvamento do core', function()
    Fake.states[40].status = { hunger = 42, thirst = 43, stress = 1 }
    SPC.saveCharacter(40, SPC.Players.get(40))
    local st = json.decode(DB.scalar('SELECT status FROM characters WHERE citizenid = ?', { cid40 }))
    eq(st.hunger, 42)
end)

-- Banco ---------------------------------------------------------------------
Fake.coords[40] = { x = BRANCH.x + 1, y = BRANCH.y, z = BRANCH.z }
Fake.coords[41] = { x = BRANCH.x, y = BRANCH.y + 1, z = BRANCH.z }

it('longe da agência é recusado', function()
    Fake.coords[99] = nil
    local saved = Fake.coords[40]
    Fake.coords[40] = { x = 0, y = 0, z = 0 }
    eq(SPCBank.info(40, 'branch').error, 'too_far')
    Fake.coords[40] = saved; later()
end)

it('saldo e extrato na agência', function()
    local r = SPCBank.info(40, 'branch')
    truthy(r.ok, r.error); eq(r.balance, 500000); eq(r.statement[1].reason, 'starter.grant'); later()
end)

it('saque na agência: banco → espécie, total constante', function()
    local r = SPCBank.withdraw(40, 1000, 'branch'); truthy(r.ok, r.error)
    eq(bal(acc40), 400000); eq(Fake.inv[40].money, 1000); later()
end)

it('cooldown entre operações', function()
    SPCBank.info(40, 'branch')
    eq(SPCBank.info(40, 'branch').error, 'rate_limited'); later()
end)

it('depósito: espécie → banco; sem notas suficientes é recusado', function()
    local r = SPCBank.deposit(40, 400, 'branch'); truthy(r.ok, r.error)
    eq(bal(acc40), 440000); eq(Fake.inv[40].money, 600); later()
    eq(SPCBank.deposit(40, 601, 'branch').error, 'not_enough_cash'); later()
end)

it('falha ao entregar as notas desfaz o saque (não destrói dinheiro)', function()
    Fake.failAdd = true
    eq(SPCBank.withdraw(40, 100, 'branch').error, 'inventory_full')
    Fake.failAdd = false
    eq(bal(acc40), 440000)
    eq(DB.int(DB.scalar("SELECT COUNT(*) FROM ledger_entries WHERE reason = 'cash.withdraw_revert'")), 2); later()
end)

it('caixa eletrônico: limite por operação e diário', function()
    SPC.Ledger.pay(40, 10000000, 'MINT_EVENT', 'event.prize', nil, 'test') -- R$ 100.000 para os testes seguintes
    local atm = { x = Fake.coords[40].x, y = Fake.coords[40].y, z = Fake.coords[40].z }
    eq(SPCBank.withdraw(40, 2001, 'atm', atm).error, 'over_limit'); later()
    eq(SPCBank.withdraw(40, 10, 'atm', { x = 0, y = 0, z = 0 }).error, 'too_far'); later()
    for _ = 1, 5 do local r = SPCBank.withdraw(40, 2000, 'atm', atm); truthy(r.ok, r.error); later() end
    eq(SPCBank.withdraw(40, 1, 'atm', atm).error, 'daily_limit'); later()
    truthy(SPCBank.withdraw(40, 1, 'branch').ok, 'agência não tem limite diário'); later()
end)

it('PIX com imposto acima de R$ 50.000 na mesma transação', function()
    local before40, before41 = bal(acc40), bal(acc41)
    local phone41 = SPC.Players.get(41).character.phone
    local r = SPCBank.pix(40, phone41:gsub('%D', ''), 60000, 'branch')
    truthy(r.ok, r.error); eq(r.tax, 600); eq(r.to, 'Carlos Souza')
    eq(bal(acc40), before40 - 6000000 - 60000); eq(bal(acc41), before41 + 6000000); later()
end)

it('PIX: para si mesmo, chave inválida e inexistente', function()
    eq(SPCBank.pix(40, SPC.Players.get(40).character.phone, 10, 'branch').error, 'pix_self'); later()
    eq(SPCBank.pix(40, '123', 10, 'branch').error, 'pix_key_invalid'); later()
    eq(SPCBank.pix(40, '11900000000', 10, 'branch').error, 'pix_key_not_found'); later()
end)

it('PIX pelo celular não exige proximidade', function()
    Fake.coords[40] = { x = 0, y = 0, z = 0 }
    truthy(SPCBank.pix(40, SPC.Players.get(41).character.phone, 10, 'phone').ok); later()
    eq(SPCBank.withdraw(40, 10, 'phone').error, 'invalid_place'); later()
end)

it('reconciliação continua zerada após todas as operações', function()
    eq(#DB.query([[SELECT b.id FROM bank_accounts b LEFT JOIN ledger_entries e ON e.account_id = b.id
        GROUP BY b.id, b.balance HAVING b.balance <> COALESCE(SUM(e.amount), 0)]]), 0)
    eq(#DB.query('SELECT tx_id FROM ledger_entries GROUP BY tx_id HAVING SUM(amount) <> 0'), 0)
end)

return results
