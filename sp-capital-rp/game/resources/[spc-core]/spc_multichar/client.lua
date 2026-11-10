-- Câmera no mirante, NUI de personagens e devolução do controle após a escolha.
local CAM_POS = vector3(-1338.0, -1283.0, 30.0) -- vista da orla (provisório até o MLO da Paulistana)
local CAM_LOOK = vector3(-1000.0, -900.0, 60.0)
local cam, open = nil, false

local function setHud(visible)
    if GetResourceState('spc_hud') == 'started' then exports.spc_hud:SetVisible(visible) end
end

local function close()
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ t = 'close' })
    if cam then
        RenderScriptCams(false, true, 800, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function fetchList()
    for _ = 1, 15 do -- a sessão do servidor pode ainda estar sendo criada
        local r = lib.callback.await('spc_core:characters:list', false)
        if r and r.ok then return r end
        Wait(1000)
    end
end

local function openSelector()
    if open or LocalPlayer.state.loaded then return end
    open = true
    local ped = PlayerPedId()
    SetEntityCoords(ped, CAM_POS.x, CAM_POS.y, CAM_POS.z - 20.0, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    DisplayRadar(false)
    setHud(false)

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', CAM_POS.x, CAM_POS.y, CAM_POS.z, 0.0, 0.0, 0.0, 60.0, false, 0)
    PointCamAtCoord(cam, CAM_LOOK.x, CAM_LOOK.y, CAM_LOOK.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)

    local data = fetchList()
    if not data then
        open = false
        return lib.notify({ title = 'SP Capital', description = 'Não foi possível carregar seus personagens. Reconecte.', type = 'error' })
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ t = 'open', characters = data.characters, slots = data.slots, nationalities = data.nationalities })
end

RegisterNUICallback('create', function(payload, cb)
    local r = lib.callback.await('spc_core:characters:create', false, payload)
    if r and r.ok then
        local list = lib.callback.await('spc_core:characters:list', false)
        r.characters = list and list.characters or nil
    end
    cb(r or { ok = false })
end)

RegisterNUICallback('select', function(payload, cb)
    local r = lib.callback.await('spc_core:characters:select', false, payload and payload.citizenid)
    cb(r or { ok = false })
    if r and r.ok then close() end
end)

AddEventHandler('spc_core:client:spawned', function()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    setHud(true)
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    openSelector()
end)
