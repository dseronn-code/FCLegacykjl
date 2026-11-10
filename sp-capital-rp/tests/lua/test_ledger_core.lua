local L = SPC.LedgerCore
local cfg = SPC.Config.Ledger

local function leg(from, to, amount, reason)
    return { from = from, to = to, amount = amount, reason = reason or 'test.move' }
end

local function sum(entries)
    local s = 0
    for _, e in ipairs(entries) do s = s + e.amount end
    return s
end

describe('LedgerCore.validate', function()
    it('aceita movimento simples entre contas', function()
        truthy(L.validate({ legs = { leg({ id = 1 }, { id = 2 }, 100) } }, cfg))
    end)
    it('recusa valores inválidos', function()
        for _, v in ipairs({ 0, -1, 1.5, '100', cfg.MaxAmount + 1 }) do
            local ok, e = L.validate({ legs = { leg({ id = 1 }, { id = 2 }, v) } }, cfg)
            truthy(not ok); eq(e, 'invalid_amount', tostring(v))
        end
    end)
    it('recusa motivo fora do padrão', function()
        local _, e = L.validate({ legs = { leg({ id = 1 }, { id = 2 }, 1, 'Pix') } }, cfg); eq(e, 'invalid_reason')
    end)
    it('recusa conta de sistema desconhecida, mesma conta e sistema→sistema', function()
        local _, e = L.validate({ legs = { leg({ system = 'MINT_FAKE' }, { id = 2 }, 1) } }, cfg); eq(e, 'invalid_account')
        _, e = L.validate({ legs = { leg({ id = 2 }, { id = 2 }, 1) } }, cfg); eq(e, 'same_account')
        _, e = L.validate({ legs = { leg({ system = 'MINT_SALARY' }, { system = 'SINK_TAX' }, 1) } }, cfg); eq(e, 'invalid_account')
        _, e = L.validate({ legs = { leg({ id = 1, system = 'MINT_SALARY' }, { id = 2 }, 1) } }, cfg); eq(e, 'invalid_account')
    end)
    it('recusa transação vazia, excesso de movimentos e txId inválido', function()
        local _, e = L.validate({ legs = {} }, cfg); eq(e, 'invalid_tx')
        local many = {}
        for i = 1, cfg.MaxLegs + 1 do many[i] = leg({ id = 1 }, { id = 2 }, 1) end
        _, e = L.validate({ legs = many }, cfg); eq(e, 'invalid_tx')
        _, e = L.validate({ txId = 'x', legs = { leg({ id = 1 }, { id = 2 }, 1) } }, cfg); eq(e, 'invalid_tx')
    end)
end)

describe('LedgerCore.accountIds', function()
    it('ids únicos em ordem crescente (ordem de bloqueio)', function()
        local ids = L.accountIds({ legs = { leg({ id = 9 }, { id = 3 }, 1), leg({ id = 3 }, { system = 'SINK_TAX' }, 1) } })
        eq(#ids, 2); eq(ids[1], 3); eq(ids[2], 9)
    end)
end)

describe('LedgerCore.plan', function()
    local function accounts()
        return { [1] = { balance = 1000, frozen = 0, kind = 'checking' },
                 [2] = { balance = 0, frozen = 0, kind = 'checking' },
                 [3] = { balance = 50, frozen = 1, kind = 'checking' },
                 [4] = { balance = 0, frozen = 0, kind = 'government' } }
    end

    it('transferência gera débito e crédito que somam zero', function()
        local p = L.plan({ legs = { leg({ id = 1 }, { id = 2 }, 300) } }, accounts(), cfg)
        eq(p.balances[1], 700); eq(p.balances[2], 300); eq(#p.entries, 2); eq(sum(p.entries), 0)
        eq(p.entries[1].balanceAfter, 700); eq(p.entries[2].balanceAfter, 300)
    end)
    it('saldo insuficiente', function()
        local p, e = L.plan({ legs = { leg({ id = 1 }, { id = 2 }, 1001) } }, accounts(), cfg)
        eq(p, nil); eq(e, 'insufficient_funds')
    end)
    it('conta congelada não pode ser debitada, mas pode receber', function()
        local _, e = L.plan({ legs = { leg({ id = 3 }, { id = 2 }, 1) } }, accounts(), cfg); eq(e, 'account_frozen')
        local p = L.plan({ legs = { leg({ id = 1 }, { id = 3 }, 10) } }, accounts(), cfg); eq(p.balances[3], 60)
    end)
    it('frozen = 0 vindo do banco NÃO é tratado como congelada', function()
        truthy(L.plan({ legs = { leg({ id = 1 }, { id = 2 }, 1) } }, accounts(), cfg))
    end)
    it('conta inexistente', function()
        local _, e = L.plan({ legs = { leg({ id = 1 }, { id = 99 }, 1) } }, accounts(), cfg); eq(e, 'account_not_found')
    end)
    it('múltiplos movimentos são sequenciais e atômicos (compra com imposto)', function()
        local tx = { legs = { leg({ id = 1 }, { id = 2 }, 900, 'shop.buy'), leg({ id = 1 }, { system = 'SINK_TAX' }, 100, 'tax.sale') } }
        local p = L.plan(tx, accounts(), cfg)
        eq(p.balances[1], 0); eq(p.balances[2], 900); eq(#p.entries, 4); eq(sum(p.entries), 0)
        tx.legs[2].amount = 101
        local _, e = L.plan(tx, accounts(), cfg); eq(e, 'insufficient_funds')
    end)
    it('mint para conta real', function()
        local p = L.plan({ legs = { leg({ system = 'MINT_STARTER' }, { id = 2 }, 500000, 'starter.grant') } }, accounts(), cfg)
        eq(p.balances[2], 500000); eq(p.entries[1].systemAccount, 'MINT_STARTER'); eq(p.entries[1].amount, -500000)
    end)
    it('governo não fica negativo por padrão', function()
        local _, e = L.plan({ legs = { leg({ id = 4 }, { id = 2 }, 1, 'job.pay') } }, accounts(), cfg); eq(e, 'insufficient_funds')
    end)
    it('só retorna saldos que mudaram', function()
        local tx = { legs = { leg({ id = 1 }, { id = 2 }, 10), leg({ id = 2 }, { id = 1 }, 10) } }
        local p = L.plan(tx, accounts(), cfg)
        eq(next(p.balances), nil); eq(#p.entries, 4)
    end)
end)

describe('LedgerCore.flows', function()
    it('separa mint e sink; CASH_VAULT é neutro', function()
        local m, s = L.flows({ legs = {
            leg({ system = 'MINT_SALARY' }, { id = 1 }, 100),
            leg({ id = 1 }, { system = 'SINK_TAX' }, 15),
            leg({ id = 1 }, { system = 'CASH_VAULT' }, 50) } }, cfg)
        eq(m, 100); eq(s, 15)
    end)
end)
