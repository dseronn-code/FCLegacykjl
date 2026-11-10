-- Comandos de desenvolvimento — substituem a tela de personagens até o spc_multichar existir.
-- Só são registrados com `setr spc_dev 1` (NUNCA em produção).
if GetConvarInt('spc_dev', 0) ~= 1 then return end

print('^3[spc_core] MODO DE DESENVOLVIMENTO ATIVO (spc_dev 1) — não use em produção^0')

local function reply(src, msg)
    if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { 'SPC', msg } }) end
end

RegisterCommand('spc_personagens', function(src)
    local s = SPC.Players.get(src)
    if not s then return end
    for _, c in ipairs(SPC.Characters.list(s.accountId)) do
        reply(src, ('%s — %s %s (%s)'):format(c.citizenid, c.firstName, c.lastName, c.birthdate))
    end
end, false)

-- /spc_criar Nome Sobrenome AAAA-MM-DD m|f|x
RegisterCommand('spc_criar', function(src, args)
    local s = SPC.Players.get(src)
    if not s then return end
    local ok, res = SPC.Characters.create(s, { firstName = args[1], lastName = args[2], birthdate = args[3], gender = args[4] })
    reply(src, ok and ('Criado: ' .. res) or ('Erro: ' .. tostring(res)))
end, false)

RegisterCommand('spc_entrar', function(src, args)
    local s = SPC.Players.get(src)
    if not s then return end
    local ok, err = SPC.Characters.select(s, args[1])
    if not ok then reply(src, 'Erro: ' .. tostring(err)) end
end, false)

RegisterCommand('spc_saldo', function(src)
    local s = SPC.Players.get(src)
    if not s or not s.character then return end
    reply(src, 'Saldo: ' .. SPC.Util.formatBRL(SPC.Ledger.balance(s.character.bankAccountId) or 0))
end, false)
