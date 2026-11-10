-- API pública do spc_core para outros recursos do servidor.
-- Spec: docs/sp-capital-rp/specs/spc_core.md §6 · docs/sp-capital-rp/specs/ledger.md §5

exports('GetPlayer', function(src) return SPC.Players.snapshot(src) end)
exports('GetSourceByCitizenId', function(citizenid) return SPC.Players.sourceByCitizen(citizenid) end)
exports('HasPermission', function(src, perm) return SPC.Permissions.has(src, perm) end)

exports('GetBankAccountId', function(src)
    local s = SPC.Players.get(src)
    return s and s.character and s.character.bankAccountId or nil
end)

exports('Outranks', function(a, b) return SPC.Permissions.outranks(a, b) end)

-- Grupos (empregos/facções) no formato do ox_inventory: { nome = grau }. Preenchidos pelas specs de empregos.
exports('GetGroups', function(src)
    local s = SPC.Players.get(src)
    return s and s.groups or {}
end)

exports('SetGroup', function(src, name, grade)
    local s = SPC.Players.get(src)
    if not s or type(name) ~= 'string' then return false end
    s.groups = s.groups or {}
    s.groups[name] = grade
    Player(src).state:set('groups', s.groups, true)
    TriggerEvent('spc_core:server:groupsChanged', src, s.groups)
    return true
end)

exports('RegisterPermissionProvider', function(fn)
    SPC.Permissions.registerProvider(fn, GetInvokingResource())
end)

-- Dinheiro — o recurso chamador é registrado em ledger_tx.resource para auditoria
exports('Execute', function(tx, actor)
    return SPC.Ledger.execute(tx, actor, GetInvokingResource())
end)

exports('Transfer', function(fromId, toId, amount, reason, ref, actor)
    return SPC.Ledger.transfer(fromId, toId, amount, reason, ref, actor, GetInvokingResource())
end)

exports('Pay', function(src, amount, from, reason, ref)
    return SPC.Ledger.pay(src, amount, from, reason, ref, GetInvokingResource())
end)

exports('Charge', function(src, amount, to, reason, ref)
    return SPC.Ledger.charge(src, amount, to, reason, ref, GetInvokingResource())
end)

exports('GetBalance', function(accountId) return SPC.Ledger.balance(accountId) end)

exports('GetStatement', function(accountId, limit) return SPC.Ledger.statement(accountId, limit) end)
exports('GetDebitedToday', function(accountId, reason) return SPC.Ledger.debitedToday(accountId, reason) end)

--- Conta corrente pelo telefone do personagem (chave PIX). Retorna { accountId, citizenid, name } ou nil.
exports('GetAccountByPhone', function(phone)
    if type(phone) ~= 'string' or #phone > 16 then return nil end
    local r = SPC.DB.single([[
        SELECT b.id, c.citizenid, c.first_name, c.last_name FROM characters c
        JOIN bank_accounts b ON b.owner_type = 'character' AND b.owner_id = c.id AND b.kind = 'checking'
        WHERE c.phone_number = ? AND c.deleted_at IS NULL AND c.ck_at IS NULL]], { phone })
    if not r then return nil end
    return { accountId = SPC.DB.int(r.id), citizenid = r.citizenid, name = r.first_name .. ' ' .. r.last_name }
end)
