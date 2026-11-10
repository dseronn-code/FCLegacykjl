-- Persistência em lote de posição/status e tratamento de desconexão.
-- Spec: docs/sp-capital-rp/specs/spc_core.md §4.4
local DB, Config = SPC.DB, SPC.Config

local function currentPosition(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if c.x == 0.0 and c.y == 0.0 then return nil end -- entidade ainda não sincronizada
    return { x = math.floor(c.x * 100) / 100, y = math.floor(c.y * 100) / 100, z = math.floor(c.z * 100) / 100,
        h = math.floor(GetEntityHeading(ped) * 10) / 10 }
end

local function saveCharacter(src, session)
    local c = session.character
    if not c then return end
    local pos = currentPosition(src)
    local status = Player(src).state.status or c.status
    DB.update('UPDATE characters SET position = COALESCE(?, position), status = ?, last_played_at = NOW() WHERE id = ?',
        { pos and json.encode(pos) or nil, json.encode(status or {}), c.id })
end

SPC.saveCharacter = saveCharacter

-- Salvamento periódico escalonado em lotes para não concentrar queries num único tick
CreateThread(function()
    while true do
        Wait(Config.SaveIntervalMs)
        local list = {}
        for src, s in pairs(SPC.Players.bySource) do
            if s.character then list[#list + 1] = src end
        end
        for i, src in ipairs(list) do
            local s = SPC.Players.get(src)
            if s then
                local ok, err = pcall(saveCharacter, src, s)
                if not ok then SPC.Log('character', 'save_failed', { src = src, error = tostring(err) }, 'warn') end
            end
            if i % Config.SaveBatchSize == 0 then Wait(Config.SaveBatchDelayMs) end
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local s = SPC.Players.get(src)
    if not s then return end
    pcall(saveCharacter, src, s)
    local minutes = math.floor((os.time() - (s.joinedAt or os.time())) / 60)
    DB.update('UPDATE accounts SET playtime_minutes = playtime_minutes + ? WHERE id = ?', { minutes, s.accountId })
    SPC.Players.remove(src)
    SPC.Limiter:clear(src .. ':')
    SPC.Log('connection', 'dropped', {
        accountId = s.accountId, citizenid = s.character and s.character.citizenid or nil,
        reason = reason, minutes = minutes,
    })
    TriggerEvent('spc_core:server:playerDropped', src, s.character and s.character.citizenid or nil)
end)

-- Ao parar o recurso (restart programado): salva todos
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, s in pairs(SPC.Players.bySource) do pcall(saveCharacter, src, s) end
end)
