-- Ciclo de 60 s sobre os personagens carregados. Sem queries: o spc_core persiste o state bag `status`.
local N = SPCNeeds.Core
local core = exports.spc_core
local TICK_MS = 60000
local WARN_EVERY = 5 -- ciclos
local tick = 0

local function setStatus(src, status)
    Player(src).state:set('status', status, true)
end

local function getStatus(src)
    return N.normalize(Player(src).state.status)
end

local function loaded(src)
    local p = core:GetPlayer(src)
    return p and p.character ~= nil
end

AddEventHandler('spc_core:server:characterLoaded', function(src)
    setStatus(src, N.normalize(Player(src).state.status))
end)

local function factorFor(src)
    local state = Player(src).state
    if state.staffMode then return 0 end
    if (state.jailMinutes or 0) > 0 then return 0.5 end
    if state.downed then return 0 end -- caído (spc_ems)
    return 1
end

function SPCNeeds.tickPlayer(src)
    local s = N.decay(getStatus(src), TICK_MS / 60000, factorFor(src))
    setStatus(src, s)
    local dmg = N.starveDamage(s)
    if dmg > 0 then TriggerClientEvent('spc_needs:client:starve', src, dmg) end
    if tick % WARN_EVERY == 0 and N.isLow(s) then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Corpo', description = 'Você está com fome ou sede.', type = 'warning' })
    end
end

CreateThread(function()
    while true do
        Wait(TICK_MS)
        tick = tick + 1
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if loaded(src) then SPCNeeds.tickPlayer(src) end
        end
    end
end)

-- Uso de item (evento LOCAL do ox_inventory, disparado após o cliente concluir o uso)
AddEventHandler('ox_inventory:usedItem', function(playerId, itemName)
    if not loaded(playerId) then return end
    local s = N.applyItem(getStatus(playerId), itemName)
    if s then setStatus(playerId, s) end
end)

exports('GetStatus', function(src) return getStatus(src) end)

exports('AddStress', function(src, amount, reason)
    if type(amount) ~= 'number' or not loaded(src) then return false end
    local s = getStatus(src)
    s.stress = math.max(0, math.min(100, s.stress + amount))
    setStatus(src, s)
    return true
end)

exports('SetStatus', function(src, key, value)
    if N.Defaults[key] == nil or type(value) ~= 'number' or not loaded(src) then return false end
    local s = getStatus(src)
    s[key] = math.max(0, math.min(100, value))
    setStatus(src, s)
    if GetResourceState('spc_logs') == 'started' then
        exports.spc_logs:Log('needs', 'set', { src = src, key = key, value = s[key], resource = GetInvokingResource() })
    end
    return true
end)
