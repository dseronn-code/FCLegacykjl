-- Testes de integração: Lua real do spc_core + MariaDB real.
local results = { passed = 0, failed = 0, failures = {} }
local function it(name, fn)
    local ok, err = pcall(fn)
    if ok then results.passed = results.passed + 1
    else results.failed = results.failed + 1; table.insert(results.failures, name .. ': ' .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or '') .. ' esperado ' .. tostring(b) .. ', obtido ' .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or 'esperado verdadeiro', 2) end end

local DB = SPC.DB
local function q1(sql, p) return DB.single(sql, p) end
local function balanceOf(id) return DB.int(DB.scalar('SELECT balance FROM bank_accounts WHERE id = ?', { id })) end
local function txCount() return DB.int(DB.scalar('SELECT COUNT(*) FROM ledger_tx')) end

local function connect(src, license, discord)
    Fake.identifiers[src] = { license = license, discord = discord }
    local done = { called = false }
    local deferrals = {
        defer = function() end, update = function() end,
        done = function(reason) done.called = true; done.reason = reason end,
    }
    Fake.emit('playerConnecting', src, 'Jogador', nil, deferrals)
    return done
end

-- Dados iniciais
DB.update("INSERT INTO accounts (discord_id, whitelist_status) VALUES ('111', 'approved'), ('222', 'pending'), ('333', 'approved'), ('444', 'approved')")
DB.update("INSERT INTO bans (account_id, reason) VALUES (NULL, 'Cheat')")
DB.update("INSERT INTO ban_identifiers (ban_id, identifier) VALUES (1, 'license:banida')")

it('conexão aprovada vincula a license na primeira entrada', function()
    local d = connect(1, 'license:aaa', 'discord:111')
    truthy(d.called); eq(d.reason, nil, 'motivo de recusa')
    eq(q1("SELECT license FROM accounts WHERE discord_id = '111'").license, 'license:aaa')
end)

it('license diferente para o mesmo discord é recusada', function()
    local d = connect(9, 'license:outra', 'discord:111')
    truthy(d.reason and d.reason:find('vinculada'), d.reason)
end)

it('whitelist pendente é recusada', function()
    local d = connect(9, 'license:p', 'discord:222'); truthy(d.reason and d.reason:find('análise'), d.reason)
end)

it('sem conta é recusada', function()
    local d = connect(9, 'license:x', 'discord:999'); truthy(d.reason and d.reason:find('whitelist'), d.reason)
end)

it('identificador banido é recusado com id do ban', function()
    local d = connect(9, 'license:banida', 'discord:333'); truthy(d.reason and d.reason:find('#1'), d.reason)
end)

it('ban por conta (account_id) é recusado mesmo com identificadores novos', function()
    DB.update("INSERT INTO bans (account_id, reason, expires_at) SELECT id, 'RDM', NOW() + INTERVAL 1 DAY FROM accounts WHERE discord_id = '444'")
    local d = connect(9, 'license:nova', 'discord:444'); truthy(d.reason and d.reason:find('RDM'), d.reason)
end)

it('playerJoining cria a sessão com o source definitivo', function()
    Fake.identifiers[5] = { license = 'license:aaa', discord = 'discord:111' }
    Fake.emit('playerJoining', 5)
    truthy(SPC.Players.get(5), 'sessão')
end)

local create = Fake.callbacks['spc_core:characters:create']
local select = Fake.callbacks['spc_core:characters:select']
local citizen1, citizen2

it('cria personagem com conta bancária e R$ 5.000 via ledger', function()
    local r = create(5, { firstName = 'joão', lastName = 'da silva', birthdate = '1995-04-12', gender = 'm' })
    truthy(r.ok, r.error); citizen1 = r.citizenid
    local c = q1('SELECT id, first_name, last_name, cpf FROM characters WHERE citizenid = ?', { citizen1 })
    eq(c.first_name, 'João'); eq(c.last_name, 'Da Silva')
    truthy(SPC.Identity.isGameCpf(c.cpf)); truthy(not SPC.Identity.isRealCpf(c.cpf))
    local b = q1("SELECT id, number, balance FROM bank_accounts WHERE owner_type = 'character' AND owner_id = ?", { DB.int(c.id) })
    eq(DB.int(b.balance), 500000); truthy(b.number:match('^0002%-%d%d%d%d%d%d%d$'), b.number)
    eq(DB.int(DB.scalar("SELECT COUNT(*) FROM ledger_entries WHERE reason = 'starter.grant'")), 2)
end)

it('rate limit bloqueia criação seguida', function()
    local r = create(5, { firstName = 'Ana', lastName = 'Lima', birthdate = '1990-01-01', gender = 'f' })
    eq(r.error, 'rate_limited')
end)

it('valida entrada (nome inválido, menor de idade)', function()
    SPC.Limiter:clear('5:')
    eq(create(5, { firstName = 'J0ão', lastName = 'Silva', birthdate = '1990-01-01', gender = 'm' }).error, 'invalid_name_chars')
    SPC.Limiter:clear('5:')
    eq(create(5, { firstName = 'Ana', lastName = 'Silva', birthdate = '2015-01-01', gender = 'f' }).error, 'invalid_age')
end)

it('respeita o limite de slots (2)', function()
    SPC.Limiter:clear('5:')
    local r = create(5, { firstName = 'Ana', lastName = 'Lima', birthdate = '1990-01-01', gender = 'f' })
    truthy(r.ok, r.error); citizen2 = r.citizenid
    SPC.Limiter:clear('5:')
    eq(create(5, { firstName = 'Rui', lastName = 'Costa', birthdate = '1990-01-01', gender = 'm' }).error, 'no_slots')
end)

it('não seleciona personagem de outra conta', function()
    DB.update("INSERT INTO characters (citizenid, account_id, first_name, last_name, birthdate, gender, cpf, rg, phone_number) SELECT 'SPCOUTRO', id, 'X', 'Y', '1990-01-01', 'm', '000.000.001-00', '00.000.000-1', '(11) 90000-0001' FROM accounts WHERE discord_id = '333'")
    eq(select(5, 'SPCOUTRO').error, 'not_found')
end)

it('seleciona personagem: sessão, state bags e evento de spawn', function()
    SPC.Limiter:clear('5:')
    local r = select(5, citizen1); truthy(r.ok, r.error)
    eq(Fake.states[5].citizenid, citizen1); eq(Fake.states[5].loaded, true)
    local last = Fake.clientEvents[#Fake.clientEvents]
    eq(last.name, 'spc_core:client:characterLoaded'); eq(last.args[1].citizenid, citizen1)
end)

local acc1 = function() return SPC.Players.get(5).character.bankAccountId end
local acc2 = function()
    return DB.int(DB.scalar("SELECT b.id FROM bank_accounts b JOIN characters c ON c.id = b.owner_id AND b.owner_type = 'character' WHERE c.citizenid = ?", { citizen2 }))
end

it('Pay (mint) e Charge (sink)', function()
    local ok, r = SPC.Ledger.pay(5, 120000, 'MINT_SALARY', 'job.pay', { type = 'job', id = 'gari' }, 'spc_jobs')
    truthy(ok, r); eq(balanceOf(acc1()), 620000)
    ok, r = SPC.Ledger.charge(5, 20000, 'SINK_SHOP', 'shop.buy', nil, 'spc_shops')
    truthy(ok, r); eq(balanceOf(acc1()), 600000)
    eq(DB.scalar("SELECT resource FROM ledger_tx ORDER BY created_at DESC, tx_id DESC LIMIT 1"), 'spc_shops')
end)

it('saldo insuficiente não altera nada', function()
    local before = txCount()
    local ok, err = SPC.Ledger.charge(5, 600001, 'SINK_SHOP', 'shop.buy')
    eq(ok, false); eq(err, 'insufficient_funds'); eq(balanceOf(acc1()), 600000); eq(txCount(), before)
end)

it('transferência entre personagens (PIX)', function()
    local ok, r = SPC.Ledger.transfer(acc1(), acc2(), 100000, 'pix.send', nil, 'char:' .. citizen1, 'spc_bank')
    truthy(ok, r); eq(balanceOf(acc1()), 500000); eq(balanceOf(acc2()), 600000)
end)

it('idempotência: mesmo txId aplicado duas vezes só conta uma', function()
    local txId = SPC.Util.ulid(1731240000000, math.random)
    local tx = function() return { txId = txId, legs = { { from = { system = 'MINT_EVENT' }, to = { id = acc1() }, amount = 777, reason = 'event.prize' } } } end
    local ok1, r1 = SPC.Ledger.execute(tx(), 'staff:1', 'spc_admin'); truthy(ok1, r1); eq(r1.duplicate, false)
    local ok2, r2 = SPC.Ledger.execute(tx(), 'staff:1', 'spc_admin'); truthy(ok2, r2); eq(r2.duplicate, true)
    eq(balanceOf(acc1()), 500777)
end)

it('transação com vários movimentos é atômica (falha no 2º desfaz o 1º)', function()
    local b1, b2, before = balanceOf(acc1()), balanceOf(acc2()), txCount()
    local ok, err = SPC.Ledger.execute({ legs = {
        { from = { id = acc1() }, to = { id = acc2() }, amount = 1000, reason = 'shop.buy' },
        { from = { id = acc1() }, to = { system = 'SINK_TAX' }, amount = 99999999, reason = 'tax.sale' },
    } }, 'system', 'test')
    eq(ok, false); eq(err, 'insufficient_funds')
    eq(balanceOf(acc1()), b1); eq(balanceOf(acc2()), b2); eq(txCount(), before)
end)

it('conta congelada não pode ser debitada', function()
    DB.update('UPDATE bank_accounts SET frozen = 1 WHERE id = ?', { acc2() })
    local ok, err = SPC.Ledger.transfer(acc2(), acc1(), 1, 'pix.send', nil, 'system', 'test')
    eq(ok, false); eq(err, 'account_frozen')
    DB.update('UPDATE bank_accounts SET frozen = 0 WHERE id = ?', { acc2() })
end)

it('governo sem saldo não paga (não fica negativo)', function()
    local ok, err = SPC.Ledger.pay(5, 100, 1, 'job.pay', nil, 'spc_jobs')
    eq(ok, false); eq(err, 'insufficient_funds')
end)

it('entrada inválida é recusada antes do banco', function()
    local ok, err = SPC.Ledger.pay(5, '100', 'MINT_SALARY', 'job.pay'); eq(err, 'invalid_amount')
    ok, err = SPC.Ledger.pay(5, 100, 'MINT_HACK', 'job.pay'); eq(err, 'invalid_account')
end)

it('reconciliação: saldos = soma do ledger e toda transação soma zero', function()
    local bad = DB.query([[SELECT b.id FROM bank_accounts b LEFT JOIN ledger_entries e ON e.account_id = b.id
        GROUP BY b.id, b.balance HAVING b.balance <> COALESCE(SUM(e.amount), 0)]])
    eq(#bad, 0, 'contas divergentes')
    local unbalanced = DB.query('SELECT tx_id FROM ledger_entries GROUP BY tx_id HAVING SUM(amount) <> 0')
    eq(#unbalanced, 0, 'transações desbalanceadas')
end)

it('comando player.kick derruba o jogador', function()
    Fake.emit('spc:cmd:player.kick', 0, 'cmd1', { citizenid = citizen1, reason = 'Teste' }, 'staff:1')
    local d = Fake.dropped[#Fake.dropped]; eq(d.src, 5); truthy(d.reason:find('Teste'))
end)

it('playerDropped salva posição e encerra a sessão', function()
    Fake.emit('playerDropped', 5, 'saiu')
    eq(SPC.Players.get(5), nil)
    local pos = json.decode(q1('SELECT position FROM characters WHERE citizenid = ?', { citizen1 }).position)
    eq(pos.x, 100.5); eq(pos.h, 90.0)
end)

return results
