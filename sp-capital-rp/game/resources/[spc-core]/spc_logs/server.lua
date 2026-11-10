local FLUSH_MS, FLUSH_SIZE, MAX_BUFFER = 2000, 500, 20000
local LEVELS = { debug = true, info = true, warn = true, alert = true }
local devMode = GetConvarInt('spc_dev', 0) == 1

local buffer, dropped = {}, 0

local function dropOne()
    for i, e in ipairs(buffer) do
        if e.level == 'debug' then table.remove(buffer, i); dropped = dropped + 1; return end
    end
    table.remove(buffer, 1)
    dropped = dropped + 1
end

local function flush()
    if #buffer == 0 then return end
    if GetResourceState('spc_bridge') ~= 'started' then
        if devMode then
            for _, e in ipairs(buffer) do print('[spc_logs] ' .. json.encode(e)) end
            buffer = {}
        end
        return -- mantém em memória até a ponte subir (limitado a MAX_BUFFER)
    end
    local batch = buffer
    buffer = {}
    TriggerEvent('spc_bridge:logs', json.encode({ entries = batch, dropped = dropped }))
    dropped = 0
end

exports('Log', function(category, action, data, level)
    level = LEVELS[level] and level or 'info'
    if type(category) ~= 'string' or type(action) ~= 'string' then return end
    local entry = {
        ts = os.time() * 1000 + GetGameTimer() % 1000,
        cat = category, action = action, level = level,
        resource = GetInvokingResource(), data = data,
    }
    if type(data) == 'table' and data.src and GetResourceState('spc_core') == 'started' then
        local p = exports.spc_core:GetPlayer(data.src)
        if p then
            entry.license = p.license
            entry.citizenid = p.character and p.character.citizenid or nil
        end
    end
    if level == 'alert' then print(('^1[spc_logs] ALERTA %s.%s %s^0'):format(category, action, json.encode(data or {}))) end

    if #buffer >= MAX_BUFFER then dropOne() end
    buffer[#buffer + 1] = entry
    if #buffer >= FLUSH_SIZE then flush() end
end)

CreateThread(function()
    while true do
        Wait(FLUSH_MS)
        flush()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then flush() end
end)
