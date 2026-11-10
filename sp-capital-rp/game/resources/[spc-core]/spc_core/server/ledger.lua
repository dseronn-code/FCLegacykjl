-- Ledger financeiro: camada de banco sobre o núcleo puro (shared/ledger_core.lua).
-- Spec: docs/sp-capital-rp/specs/ledger.md
local LedgerCore, DB, Util = SPC.LedgerCore, SPC.DB, SPC.Util
local cfg = SPC.Config.Ledger

SPC.Ledger = {}
local Ledger = SPC.Ledger

local function nowMs()
    return os.time() * 1000 + GetGameTimer() % 1000
end

--- Executa a transação usando um `query` de transação já aberta (permite compor com outras escritas).
-- Retorna result ({txId, duplicate, plan}) ou nil, erro. Em erro, o chamador deve fazer ROLLBACK.
function Ledger.executeWith(query, tx, actor, resource)
    local ok, err = LedgerCore.validate(tx, cfg)
    if not ok then return nil, err end

    local txId = tx.txId or Util.ulid(nowMs(), math.random)
    local res = query('INSERT IGNORE INTO ledger_tx (tx_id, actor, resource) VALUES (?, ?, ?)', { txId, actor, resource })
    if (DB.int(res and res.affectedRows) or 0) == 0 then
        return { txId = txId, duplicate = true }
    end

    local ids = LedgerCore.accountIds(tx)
    local accounts = {}
    if #ids > 0 then
        local rows = query(('SELECT id, balance, frozen, kind FROM bank_accounts WHERE id IN (%s) ORDER BY id FOR UPDATE')
            :format(DB.placeholders(#ids)), ids)
        for _, row in ipairs(rows or {}) do
            accounts[DB.int(row.id)] = { balance = DB.int(row.balance), frozen = DB.int(row.frozen), kind = row.kind }
        end
    end

    local plan, planErr = LedgerCore.plan(tx, accounts, cfg)
    if not plan then return nil, planErr end

    for id, balance in pairs(plan.balances) do
        query('UPDATE bank_accounts SET balance = ? WHERE id = ?', { balance, id })
    end

    local values, params, k = {}, {}, 0
    for _, e in ipairs(plan.entries) do
        values[#values + 1] = '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        local p = { txId, e.leg, e.accountId, e.systemAccount, e.amount, e.balanceAfter, e.reason,
            e.refType, e.refId ~= nil and tostring(e.refId) or nil, actor }
        -- contador explícito: p[i] pode ser nil (conta de sistema, sem ref) e #params não seria confiável
        for i = 1, 10 do k = k + 1; params[k] = p[i] end
    end
    -- nil → NULL é resolvido por DB.transaction/bindNulls sem deslocar os parâmetros.
    query(('INSERT INTO ledger_entries (tx_id, leg, account_id, system_account, amount, balance_after, reason, ref_type, ref_id, actor) VALUES %s')
        :format(table.concat(values, ', ')), params)

    return { txId = txId, duplicate = false, plan = plan }
end

--- Logs, métricas e alertas após COMMIT.
function Ledger.afterCommit(tx, result, actor, resource)
    if result.duplicate then return end
    local mint, sink = LedgerCore.flows(tx, cfg)
    local biggest = 0
    for _, leg in ipairs(tx.legs) do if leg.amount > biggest then biggest = leg.amount end end
    SPC.Log('money', 'tx', {
        txId = result.txId, actor = actor, resource = resource, mint = mint, sink = sink, legs = tx.legs,
    }, biggest >= cfg.AlertSingleMovement and 'alert' or 'info')
    TriggerEvent('spc_core:server:ledgerCommitted', result.txId, mint, sink, result.plan.balances)
end

--- Executa a transação em sua própria transação de banco.
-- Retorna true, { txId, duplicate } ou false, códigoDeErro.
function Ledger.execute(tx, actor, resource)
    actor = actor or 'system'
    local ok, err = LedgerCore.validate(tx, cfg)
    if not ok then return false, err end

    -- txId definido antes para que uma nova tentativa após falha de rede seja idempotente
    tx.txId = tx.txId or Util.ulid(nowMs(), math.random)

    local result, failure
    local committed = DB.transaction(function(query)
        local r, e = Ledger.executeWith(query, tx, actor, resource)
        if not r then failure = e; return false end
        result = r
        return true
    end)
    if not committed then return false, failure or 'db_error' end

    Ledger.afterCommit(tx, result, actor, resource)
    return true, { txId = result.txId, duplicate = result.duplicate }
end

--- Converte 'MINT_X' | id numérico em referência de conta.
local function accountRef(v)
    if type(v) == 'string' then return { system = v } end
    return { id = v }
end

local function playerContext(src)
    local s = SPC.Players.get(src)
    if not s or not s.character then return nil end
    return s, 'char:' .. s.character.citizenid
end

--- Credita o personagem ativo. `from` = conta de sistema (ex.: 'MINT_SALARY') ou id de conta real.
function Ledger.pay(src, amount, from, reason, ref, resource)
    local s, actor = playerContext(src)
    if not s then return false, 'player_not_loaded' end
    return Ledger.execute({ legs = { { from = accountRef(from), to = { id = s.character.bankAccountId },
        amount = amount, reason = reason, ref = ref } } }, actor, resource)
end

--- Debita o personagem ativo. `to` = conta de sistema (ex.: 'SINK_SHOP') ou id de conta real.
function Ledger.charge(src, amount, to, reason, ref, resource)
    local s, actor = playerContext(src)
    if not s then return false, 'player_not_loaded' end
    return Ledger.execute({ legs = { { from = { id = s.character.bankAccountId }, to = accountRef(to),
        amount = amount, reason = reason, ref = ref } } }, actor, resource)
end

function Ledger.transfer(fromId, toId, amount, reason, ref, actor, resource)
    return Ledger.execute({ legs = { { from = { id = fromId }, to = { id = toId }, amount = amount,
        reason = reason, ref = ref } } }, actor, resource)
end

function Ledger.balance(accountId)
    return DB.int(DB.scalar('SELECT balance FROM bank_accounts WHERE id = ?', { accountId }))
end
