-- Núcleo puro do ledger: validação e planejamento de transações (sem banco).
-- Spec: docs/sp-capital-rp/specs/ledger.md §3–4
SPC = SPC or {}
local LedgerCore = {}

local REASON_PATTERN = '^[a-z_]+%.[a-z_]+$'

-- Uma conta é { id = <bank_account_id> } ou { system = 'MINT_SALARY' }.
local function accountKey(acc)
    if acc.id then return 'id:' .. tostring(acc.id) end
    return 'sys:' .. acc.system
end

local function validAccount(acc, cfg)
    if type(acc) ~= 'table' then return false end
    if acc.id ~= nil then
        local id = type(acc.id) == 'number' and math.tointeger(acc.id) or nil
        return id ~= nil and id > 0 and acc.system == nil
    end
    return type(acc.system) == 'string' and cfg.SystemAccounts[acc.system] ~= nil
end

--- Valida o formato de uma transação. Retorna true ou false, código de erro.
function LedgerCore.validate(tx, cfg)
    if type(tx) ~= 'table' or type(tx.legs) ~= 'table' then return false, 'invalid_tx' end
    local n = #tx.legs
    if n < 1 or n > cfg.MaxLegs then return false, 'invalid_tx' end
    if tx.txId ~= nil and not SPC.Util.isUlid(tx.txId) then return false, 'invalid_tx' end
    for _, leg in ipairs(tx.legs) do
        if type(leg) ~= 'table' then return false, 'invalid_tx' end
        -- math.tointeger aceita strings numéricas no Lua 5.4: exigir tipo number explicitamente
        local amount = type(leg.amount) == 'number' and math.tointeger(leg.amount) or nil
        if not amount or amount < 1 or amount > cfg.MaxAmount then return false, 'invalid_amount' end
        if type(leg.reason) ~= 'string' or #leg.reason > 48 or not leg.reason:match(REASON_PATTERN) then
            return false, 'invalid_reason'
        end
        if not validAccount(leg.from, cfg) or not validAccount(leg.to, cfg) then return false, 'invalid_account' end
        if accountKey(leg.from) == accountKey(leg.to) then return false, 'same_account' end
        if leg.from.system and leg.to.system then return false, 'invalid_account' end
        if leg.ref ~= nil and (type(leg.ref) ~= 'table' or type(leg.ref.type) ~= 'string') then
            return false, 'invalid_tx'
        end
    end
    return true
end

--- Lista ordenada (crescente) dos ids de contas reais envolvidas — ordem de bloqueio FOR UPDATE.
function LedgerCore.accountIds(tx)
    local seen, ids = {}, {}
    for _, leg in ipairs(tx.legs) do
        for _, acc in ipairs({ leg.from, leg.to }) do
            if acc.id then
                local id = math.tointeger(acc.id)
                if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
        end
    end
    table.sort(ids)
    return ids
end

--- Planeja a transação sobre os saldos atuais.
-- `accounts`: mapa id → { balance, frozen, kind } (lido com FOR UPDATE).
-- Retorna { balances = {id → novo saldo}, entries = {...} } ou nil, erro.
function LedgerCore.plan(tx, accounts, cfg)
    local balances = {}
    for id, acc in pairs(accounts) do balances[id] = math.tointeger(acc.balance) end

    local entries = {}
    for i, leg in ipairs(tx.legs) do
        local amount = math.tointeger(leg.amount)
        local ref = leg.ref or {}

        if leg.from.id then
            local id = math.tointeger(leg.from.id)
            local acc = accounts[id]
            if not acc then return nil, 'account_not_found' end
            -- MariaDB devolve TINYINT como número: 0 é verdadeiro em Lua, por isso a comparação explícita
            if acc.frozen == true or acc.frozen == 1 then return nil, 'account_frozen' end
            local after = balances[id] - amount
            local mayGoNegative = acc.kind == 'government' and cfg.GovernmentCanGoNegative
            if after < 0 and not mayGoNegative then return nil, 'insufficient_funds' end
            balances[id] = after
            entries[#entries + 1] = { leg = i, accountId = id, amount = -amount, balanceAfter = after,
                reason = leg.reason, refType = ref.type, refId = ref.id }
        else
            entries[#entries + 1] = { leg = i, systemAccount = leg.from.system, amount = -amount,
                reason = leg.reason, refType = ref.type, refId = ref.id }
        end

        if leg.to.id then
            local id = math.tointeger(leg.to.id)
            if not accounts[id] then return nil, 'account_not_found' end
            balances[id] = balances[id] + amount
            entries[#entries + 1] = { leg = i, accountId = id, amount = amount, balanceAfter = balances[id],
                reason = leg.reason, refType = ref.type, refId = ref.id }
        else
            entries[#entries + 1] = { leg = i, systemAccount = leg.to.system, amount = amount,
                reason = leg.reason, refType = ref.type, refId = ref.id }
        end
    end

    local changed = {}
    for id, b in pairs(balances) do
        if b ~= math.tointeger(accounts[id].balance) then changed[id] = b end
    end
    return { balances = changed, entries = entries }
end

--- Soma de mint/sink da transação, para métricas (centavos, positivos).
function LedgerCore.flows(tx, cfg)
    local mint, sink = 0, 0
    for _, leg in ipairs(tx.legs) do
        if leg.from.system and cfg.SystemAccounts[leg.from.system] == 'mint' then mint = mint + leg.amount end
        if leg.to.system and cfg.SystemAccounts[leg.to.system] == 'sink' then sink = sink + leg.amount end
    end
    return mint, sink
end

SPC.LedgerCore = LedgerCore
return LedgerCore
