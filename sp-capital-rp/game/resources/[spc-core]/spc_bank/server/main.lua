-- Operações do Banco Capital. Toda decisão no servidor; o cliente só escolhe a operação e o valor.
local B, Cfg = SPCBank.Core, SPCBank.Config
local L = Cfg.Limits
local core, inv = exports.spc_core, exports.ox_inventory
local last = {}

local function log(action, data, level)
    if GetResourceState('spc_logs') == 'started' then exports.spc_logs:Log('bank', action, data, level) end
end

local function context(src, where, atmCoords)
    local p = core:GetPlayer(src)
    if not p or not p.character then return nil, 'not_loaded' end
    local now = GetGameTimer()
    if last[src] and now - last[src] < Cfg.CooldownMs then return nil, 'rate_limited' end
    last[src] = now

    local pos = GetEntityCoords(GetPlayerPed(src))
    if where == 'branch' then
        if not B.nearBranch(pos, Cfg.Branches, Cfg.MaxDistance) then return nil, 'too_far' end
    elseif where == 'atm' then
        -- Limitação conhecida: caixas são props do mapa (não sincronizados); o servidor confere a distância
        -- até a posição informada. Lista fixa de caixas virá após levantamento no staging (spec banco §2).
        if type(atmCoords) ~= 'table' or type(atmCoords.x) ~= 'number' or B.distance(pos, atmCoords) > Cfg.MaxDistance then
            return nil, 'too_far'
        end
    elseif where ~= 'phone' then
        return nil, 'invalid_place'
    end
    return p
end

local function balanceOf(p) return core:GetBalance(p.character.bankAccountId) or 0 end

local function withdraw(src, amount, where, atmCoords)
    local p, err = context(src, where, atmCoords)
    if not p then return { ok = false, error = err } end
    if where == 'phone' then return { ok = false, error = 'invalid_place' } end
    local isAtm = where == 'atm'
    local value, verr = B.parseAmount(amount, isAtm and L.AtmWithdrawPerOp or L.BranchWithdrawPerOp)
    if not value then return { ok = false, error = verr } end

    local acc = p.character.bankAccountId
    local reason = isAtm and 'atm.withdraw' or 'cash.withdraw'
    if isAtm and core:GetDebitedToday(acc, reason) + value * 100 > L.AtmWithdrawPerDay * 100 then
        log('limit_reached', { src = src, amount = value })
        return { ok = false, error = 'daily_limit' }
    end
    if not inv:CanCarryItem(src, 'money', value) then return { ok = false, error = 'inventory_full' } end

    local ok, res = core:Execute({ legs = { { from = { id = acc }, to = { system = 'CASH_VAULT' }, amount = value * 100, reason = reason } } },
        'char:' .. p.character.citizenid)
    if not ok then return { ok = false, error = res } end

    if not inv:AddItem(src, 'money', value) then
        -- Não coube: desfaz no ledger para não destruir dinheiro
        core:Execute({ legs = { { from = { system = 'CASH_VAULT' }, to = { id = acc }, amount = value * 100,
            reason = 'cash.withdraw_revert', ref = { type = 'tx', id = res.txId } } } }, 'system')
        return { ok = false, error = 'inventory_full' }
    end
    log('withdraw', { src = src, amount = value, where = where, txId = res.txId })
    return { ok = true, balance = balanceOf(p) }
end

local function deposit(src, amount, where, atmCoords)
    local p, err = context(src, where, atmCoords)
    if not p then return { ok = false, error = err } end
    if where == 'phone' then return { ok = false, error = 'invalid_place' } end
    local value, verr = B.parseAmount(amount, where == 'atm' and L.AtmDepositPerOp or L.BranchDepositPerOp)
    if not value then return { ok = false, error = verr } end

    -- Só o item `money` é aceito: `dirty_money` nunca entra no banco (spec banco §1)
    if (inv:GetItemCount(src, 'money') or 0) < value then return { ok = false, error = 'not_enough_cash' } end
    if not inv:RemoveItem(src, 'money', value) then return { ok = false, error = 'not_enough_cash' } end

    local ok, res = core:Execute({ legs = { { from = { system = 'CASH_VAULT' }, to = { id = p.character.bankAccountId },
        amount = value * 100, reason = 'cash.deposit' } } }, 'char:' .. p.character.citizenid)
    if not ok then
        inv:AddItem(src, 'money', value) -- devolve as notas
        return { ok = false, error = res }
    end
    log('deposit', { src = src, amount = value, where = where, txId = res.txId })
    return { ok = true, balance = balanceOf(p) }
end

local function pix(src, phone, amount, where, atmCoords)
    local p, err = context(src, where, atmCoords)
    if not p then return { ok = false, error = err } end
    local value, verr = B.parseAmount(amount, L.PixPerOp)
    if not value then return { ok = false, error = verr } end
    local key = B.normalizePhone(phone)
    if not key then return { ok = false, error = 'pix_key_invalid' } end
    local dest = core:GetAccountByPhone(key)
    if not dest then return { ok = false, error = 'pix_key_not_found' } end
    if dest.accountId == p.character.bankAccountId then return { ok = false, error = 'pix_self' } end

    local legs, tax = B.pixLegs(p.character.bankAccountId, dest.accountId, value, L, { type = 'pix', id = dest.citizenid })
    local ok, res = core:Execute({ legs = legs }, 'char:' .. p.character.citizenid)
    if not ok then return { ok = false, error = res } end

    log('pix', { src = src, to = dest.citizenid, amount = value, tax = tax, txId = res.txId })
    local destSrc = core:GetSourceByCitizenId(dest.citizenid)
    if destSrc then
        TriggerClientEvent('ox_lib:notify', destSrc, { title = 'Banco Capital',
            description = ('PIX recebido de %s %s: R$ %d'):format(p.character.firstName, p.character.lastName, value), type = 'success' })
    end
    return { ok = true, balance = balanceOf(p), tax = tax, to = dest.name }
end

local function info(src, where, atmCoords)
    local p, err = context(src, where, atmCoords)
    if not p then return { ok = false, error = err } end
    return { ok = true, balance = balanceOf(p), statement = core:GetStatement(p.character.bankAccountId, 20),
        name = p.character.firstName .. ' ' .. p.character.lastName }
end

SPCBank.withdraw, SPCBank.deposit, SPCBank.pix, SPCBank.info = withdraw, deposit, pix, info

lib.callback.register('spc_bank:info', function(src, where, atm) return info(src, where, atm) end)
lib.callback.register('spc_bank:withdraw', function(src, amount, where, atm) return withdraw(src, amount, where, atm) end)
lib.callback.register('spc_bank:deposit', function(src, amount, where, atm) return deposit(src, amount, where, atm) end)
lib.callback.register('spc_bank:pix', function(src, phone, amount, where, atm) return pix(src, phone, amount, where, atm) end)

-- Exports para o app do celular (spec do celular)
exports('Pix', function(src, phone, amount) return pix(src, phone, amount, 'phone') end)
exports('Info', function(src) return info(src, 'phone') end)

AddEventHandler('playerDropped', function() last[source] = nil end)
