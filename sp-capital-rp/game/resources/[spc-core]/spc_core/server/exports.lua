-- API pública do spc_core para outros recursos do servidor.
-- Spec: docs/sp-capital-rp/specs/spc_core.md §6 · docs/sp-capital-rp/specs/ledger.md §5

exports('GetPlayer', function(src) return SPC.Players.snapshot(src) end)
exports('GetSourceByCitizenId', function(citizenid) return SPC.Players.sourceByCitizen(citizenid) end)
exports('HasPermission', function(src, perm) return SPC.Permissions.has(src, perm) end)

exports('GetBankAccountId', function(src)
    local s = SPC.Players.get(src)
    return s and s.character and s.character.bankAccountId or nil
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
