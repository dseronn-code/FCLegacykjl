-- Orçamento: ≤ 0,05 ms a pé e ≤ 0,10 ms em veículo. Nada de Wait(0).
local visible = false
local last = {}

local function send(key, value)
    if last[key] == value then return end
    last[key] = value
    SendNUIMessage({ t = key, v = value })
end

local function setVisible(v)
    visible = v and true or false
    SendNUIMessage({ t = 'visible', v = visible })
    if not visible then DisplayRadar(false) end
end
exports('SetVisible', setVisible)

-- Status (fome/sede/stress) vem do servidor via state bag
local function pushStatus(status)
    if type(status) ~= 'table' then return end
    SendNUIMessage({ t = 'status', v = { hunger = status.hunger, thirst = status.thirst, stress = status.stress } })
end
AddStateBagChangeHandler('status', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value) pushStatus(value) end)
AddStateBagChangeHandler('radioChannel', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    SendNUIMessage({ t = 'radio', v = (value and value > 0) and value or nil })
end)

AddEventHandler('spc_core:client:spawned', function()
    pushStatus(LocalPlayer.state.status)
    setVisible(true)
end)

-- Pé: vida, colete, voz (250 ms)
CreateThread(function()
    while true do
        Wait(250)
        if visible then
            local ped = PlayerPedId()
            send('health', math.max(0, GetEntityHealth(ped) - 100))
            send('armor', GetPedArmour(ped))
            send('talking', NetworkIsPlayerTalking(PlayerId()))
            local prox = LocalPlayer.state.proximity
            send('voice', prox and prox.index or 2)
        end
    end
end)

-- Localização (500 ms)
CreateThread(function()
    while true do
        Wait(500)
        if visible then
            local c = GetEntityCoords(PlayerPedId())
            local street = GetStreetNameFromHashKey((GetStreetNameAtCoord(c.x, c.y, c.z)))
            local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
            send('street', street .. ' · ' .. zone)
            local h = GetGameplayCamRot(2).z
            send('heading', math.floor((360.0 - ((h + 360.0) % 360.0)) % 360.0))
        end
    end
end)

-- Veículo (100 ms, só dentro de veículo)
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if visible and veh ~= 0 then
            DisplayRadar(true)
            send('vehicle', true)
            send('speed', math.floor(GetEntitySpeed(veh) * 3.6))
            send('fuel', math.floor(GetVehicleFuelLevel(veh)))
            Wait(100)
        else
            if last.vehicle then DisplayRadar(false); send('vehicle', false) end
            Wait(500)
        end
    end
end)
