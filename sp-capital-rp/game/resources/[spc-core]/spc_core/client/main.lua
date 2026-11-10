-- Cliente do spc_core: apenas aplica o spawn decidido pelo servidor. Nenhuma regra de jogo aqui.
-- GetHashKey em vez de `hash` para manter o arquivo compatível com o luac padrão usado no CI
local MODELS = { m = GetHashKey('mp_m_freemode_01'), f = GetHashKey('mp_f_freemode_01'), x = GetHashKey('mp_m_freemode_01') }

local function loadModel(model)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(model)
end

RegisterNetEvent('spc_core:client:characterLoaded', function(data)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    local model = MODELS[data.gender] or MODELS.m
    if loadModel(model) then
        SetPlayerModel(PlayerId(), model)
        SetPedDefaultComponentVariation(PlayerPedId())
        SetModelAsNoLongerNeeded(model)
    end

    local p = data.position
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z, false, false, false)
    NetworkResurrectLocalPlayer(p.x, p.y, p.z, p.h or 0.0, true, false)
    ped = PlayerPedId()
    SetEntityHeading(ped, p.h or 0.0)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

    FreezeEntityPosition(ped, false)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)
    TriggerEvent('spc_core:client:spawned', data)
end)
