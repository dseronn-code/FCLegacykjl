-- Interface do banco (alpha): menus do ox_lib. O servidor valida local, limites e saldo.
local Cfg = SPCBank.Config

local ERRORS = {
    too_far = 'Aproxime-se do caixa ou do balcão.', rate_limited = 'Aguarde um instante.',
    invalid_amount = 'Valor inválido.', over_limit = 'Valor acima do limite desta operação.',
    daily_limit = 'Limite diário de saque em caixa atingido. Vá a uma agência.',
    inventory_full = 'Você não consegue carregar esse dinheiro.', not_enough_cash = 'Você não tem esse valor em espécie.',
    insufficient_funds = 'Saldo insuficiente.', account_frozen = 'Conta bloqueada judicialmente.',
    pix_key_invalid = 'Chave PIX inválida. Use o telefone: (11) 9XXXX-XXXX.', pix_key_not_found = 'Chave PIX não encontrada.',
    pix_self = 'Você não pode fazer PIX para si mesmo.', invalid_place = 'Operação indisponível aqui.',
}

local function brl(cents)
    local s = tostring(math.floor((cents or 0) / 100)):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    return ('R$ %s,%02d'):format(s, math.floor(cents or 0) % 100)
end

local function result(r, success)
    if r and r.ok then
        lib.notify({ title = 'Banco Capital', description = success .. ' Saldo: ' .. brl(r.balance), type = 'success' })
    else
        lib.notify({ title = 'Banco Capital', description = ERRORS[r and r.error] or 'Operação não concluída.', type = 'error' })
    end
end

local function askAmount(title, max)
    local input = lib.inputDialog(title, { { type = 'number', label = 'Valor (R$)', min = 1, max = max, required = true } })
    return input and input[1]
end

local function openMenu(where, atm)
    local data = lib.callback.await('spc_bank:info', false, where, atm)
    if not data or not data.ok then return result(data) end
    local L = Cfg.Limits
    local options = {
        { title = 'Saldo: ' .. brl(data.balance), description = data.name, readOnly = true },
        { title = 'Sacar', icon = 'money-bill', onSelect = function()
            local v = askAmount('Saque', where == 'atm' and L.AtmWithdrawPerOp or L.BranchWithdrawPerOp)
            if v then result(lib.callback.await('spc_bank:withdraw', false, v, where, atm), 'Saque realizado.') end
        end },
        { title = 'Depositar', icon = 'piggy-bank', onSelect = function()
            local v = askAmount('Depósito', where == 'atm' and L.AtmDepositPerOp or L.BranchDepositPerOp)
            if v then result(lib.callback.await('spc_bank:deposit', false, v, where, atm), 'Depósito realizado.') end
        end },
        { title = 'PIX', icon = 'paper-plane', onSelect = function()
            local input = lib.inputDialog('PIX', {
                { type = 'input', label = 'Telefone de destino', placeholder = '(11) 91234-5678', required = true },
                { type = 'number', label = 'Valor (R$)', min = 1, max = L.PixPerOp, required = true },
            })
            if input then result(lib.callback.await('spc_bank:pix', false, input[1], input[2], where, atm), 'PIX enviado.') end
        end },
        { title = 'Extrato', icon = 'receipt', onSelect = function()
            local items = {}
            for _, e in ipairs(data.statement or {}) do
                items[#items + 1] = { title = (e.amount >= 0 and '+ ' or '- ') .. brl(math.abs(e.amount)), description = e.reason .. ' · ' .. (e.at or ''), readOnly = true }
            end
            lib.registerContext({ id = 'spc_bank_statement', title = 'Extrato', menu = 'spc_bank_main', options = items })
            lib.showContext('spc_bank_statement')
        end },
    }
    lib.registerContext({ id = 'spc_bank_main', title = where == 'atm' and 'Caixa eletrônico' or 'Agência Banco Capital', options = options })
    lib.showContext('spc_bank_main')
end

CreateThread(function()
    exports.ox_target:addModel(Cfg.AtmModels, { {
        name = 'spc_bank_atm', icon = 'fa-solid fa-credit-card', label = 'Usar caixa eletrônico', distance = 1.5,
        onSelect = function(data)
            local c = GetEntityCoords(data.entity)
            openMenu('atm', { x = c.x, y = c.y, z = c.z })
        end,
    } })
    for i, br in ipairs(Cfg.Branches) do
        exports.ox_target:addSphereZone({
            coords = vec3(br.coords.x, br.coords.y, br.coords.z), radius = 1.5, debug = false,
            options = { { name = 'spc_bank_branch_' .. i, icon = 'fa-solid fa-building-columns', label = br.label, onSelect = function() openMenu('branch') end } },
        })
        local blip = AddBlipForCoord(br.coords.x, br.coords.y, br.coords.z)
        SetBlipSprite(blip, 108); SetBlipColour(blip, 2); SetBlipScale(blip, 0.7); SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Banco Capital'); EndTextCommandSetBlipName(blip)
    end
end)
