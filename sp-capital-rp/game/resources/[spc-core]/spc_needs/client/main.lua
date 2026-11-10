-- Efeitos visuais de necessidades. Nenhum valor é decidido aqui.
RegisterNetEvent('spc_needs:client:starve', function(damage)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - (tonumber(damage) or 0)))
end)

local shaking = 0
AddStateBagChangeHandler('status', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    local stress = type(value) == 'table' and tonumber(value.stress) or 0
    local level = stress >= 85 and 2 or (stress >= 60 and 1 or 0)
    if level == shaking then return end
    shaking = level
    if level == 0 then StopGameplayCamShaking(false)
    else ShakeGameplayCam('HAND_SHAKE', level == 2 and 1.2 or 0.4) end
end)
