-- Cliente do spc_admin: só executa o que o servidor autorizou.
local noclip = false
local spectating = nil -- { returnTo = vec, id }

local function setNoclip(state)
    if state == nil then state = not noclip end
    noclip = state
    local ped = PlayerPedId()
    SetEntityVisible(ped, not noclip, false)
    SetEntityCollision(ped, not noclip, not noclip)
    FreezeEntityPosition(ped, noclip)
    SetEntityInvincible(ped, noclip)
    if not noclip then return end

    CreateThread(function()
        while noclip do
            local p = PlayerPedId()
            local pos = GetEntityCoords(p)
            local rot = GetGameplayCamRot(2)
            local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
            local dir = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
            local speed = IsControlPressed(0, 21) and 3.0 or (IsControlPressed(0, 19) and 0.2 or 1.0) -- Shift / Alt
            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) then move = move + dir end          -- W
            if IsControlPressed(0, 33) then move = move - dir end          -- S
            if IsControlPressed(0, 22) then move = move + vector3(0, 0, 1) end -- Espaço
            if IsControlPressed(0, 36) then move = move - vector3(0, 0, 1) end -- Ctrl
            local n = pos + move * speed
            SetEntityCoordsNoOffset(p, n.x, n.y, n.z, true, true, true)
            SetEntityHeading(p, rot.z)
            Wait(0)
        end
    end)
end

RegisterNetEvent('spc_admin:client:setNoclip', setNoclip)

RegisterNetEvent('spc_admin:client:tpm', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then
        return lib.notify({ title = 'Staff', description = 'Marque um ponto no mapa.', type = 'error' })
    end
    local c = GetBlipInfoIdCoord(blip)
    local z = 0.0
    for h = 1000.0, 0.0, -25.0 do
        RequestCollisionAtCoord(c.x, c.y, h)
        Wait(0)
        local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, h, false)
        if found then z = groundZ + 1.0 break end
    end
    lib.callback.await('spc_admin:tpm', false, { x = c.x, y = c.y, z = z })
end)

RegisterNetEvent('spc_admin:client:spectate', function(data)
    local ped = PlayerPedId()
    if not data then
        if not spectating then return end
        NetworkSetInSpectatorMode(false, ped)
        local r = spectating.returnTo
        SetEntityCoords(ped, r.x, r.y, r.z, false, false, false, false)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        spectating = nil
        return
    end
    spectating = spectating or { returnTo = GetEntityCoords(ped) }
    -- Aproxima o staff invisível para o alvo entrar no escopo do OneSync, depois observa
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, data.coords.x, data.coords.y, data.coords.z - 15.0, false, false, false, false)
    local timeout = GetGameTimer() + 5000
    local player = GetPlayerFromServerId(data.id)
    while player == -1 and GetGameTimer() < timeout do Wait(100); player = GetPlayerFromServerId(data.id) end
    if player == -1 then return lib.notify({ title = 'Staff', description = 'Alvo fora de alcance.', type = 'error' }) end
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
end)

RegisterNetEvent('spc_admin:client:revive', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    ClearPedBloodDamage(PlayerPedId())
end)
