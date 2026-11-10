-- Ambiente FiveM/oxmysql simulado para rodar o Lua real do servidor fora do FXServer.
-- `jsdb(op, sql, params)` é injetado pelo run.mjs e retorna uma Promise (aguardada com :await()).
Fake = { events = {}, callbacks = {}, clientEvents = {}, serverEvents = {}, dropped = {}, identifiers = {},
    states = {}, exportsTable = {}, now = 1000 }

local function call(op, sql, params) return jsdb(op, sql, params):await().v end

MySQL = {
    query = { await = function(sql, p) return call('query', sql, p) end },
    single = { await = function(sql, p) return call('single', sql, p) end },
    scalar = { await = function(sql, p) return call('scalar', sql, p) end },
    insert = { await = function(sql, p) return call('insert', sql, p) end },
    update = { await = function(sql, p) return call('update', sql, p) end },
}

-- Mesma semântica do oxmysql: retorno false => ROLLBACK; erro => ROLLBACK e retorna false
function MySQL.startTransaction(fn)
    call('begin')
    local ok, commit = pcall(fn, function(sql, p) return call('query', sql, p) end)
    if ok and commit ~= false then call('commit'); return true end
    if not ok then print('[fake oxmysql] erro na transação: ' .. tostring(commit)) end
    call('rollback')
    return false
end

json = { encode = function(v) return jsonEncode(v) end, decode = function(s) return jsonDecode(s) end }

function GetGameTimer() Fake.now = Fake.now + 1; return Fake.now end
function GetConvarInt() return 0 end
function GetResourceState() return 'missing' end
function GetInvokingResource() return 'test_resource' end
function GetCurrentResourceName() return 'spc_core' end
function Wait() end
function CreateThread() end

function AddEventHandler(name, fn)
    Fake.events[name] = Fake.events[name] or {}
    table.insert(Fake.events[name], fn)
end

function Fake.emit(name, src, ...)
    source = src
    for _, fn in ipairs(Fake.events[name] or {}) do fn(...) end
end

function TriggerEvent(name, ...) table.insert(Fake.serverEvents, { name = name, args = { ... } }) end
function TriggerClientEvent(name, src, ...) table.insert(Fake.clientEvents, { name = name, src = src, args = { ... } }) end
function DropPlayer(src, reason) table.insert(Fake.dropped, { src = src, reason = reason }) end
function GetPlayerIdentifierByType(src, t) return (Fake.identifiers[src] or {})[t] end
Fake.tokens = {}
function GetNumPlayerTokens(src) return #(Fake.tokens[src] or {}) end
function GetPlayerToken(src, i) return (Fake.tokens[src] or {})[i + 1] end
Fake.coords = {}
function GetPlayerPed(src) return src end
function GetEntityCoords(ped) return Fake.coords[ped] or { x = 100.5, y = 200.25, z = 30.0 } end
function GetPlayers()
    local out = {}
    for src in pairs(SPC.Players.bySource) do out[#out + 1] = tostring(src) end
    return out
end

-- Inventário simulado (ox_inventory): Fake.inv[src][item] = quantidade
Fake.inv, Fake.failAdd = {}, false
local function bag(src) Fake.inv[src] = Fake.inv[src] or {}; return Fake.inv[src] end
Fake.exportsTable.CanCarryItem = function() return true end
Fake.exportsTable.GetItemCount = function(src, item) return bag(src)[item] or 0 end
Fake.exportsTable.AddItem = function(src, item, n)
    if Fake.failAdd then return false end
    bag(src)[item] = (bag(src)[item] or 0) + n
    return true
end
Fake.exportsTable.RemoveItem = function(src, item, n)
    if (bag(src)[item] or 0) < n then return false end
    bag(src)[item] = bag(src)[item] - n
    return true
end
function GetEntityHeading() return 90.0 end

function Player(src)
    Fake.states[src] = Fake.states[src] or {}
    local bag = Fake.states[src]
    return { state = setmetatable({ set = function(_, k, v) bag[k] = v end }, { __index = bag }) }
end

-- exports(name, fn) registra; exports.recurso:Nome(...) chama o registrado (o self é descartado, como no FiveM)
local resourceProxy = setmetatable({}, { __index = function(_, name)
    return function(_, ...) return Fake.exportsTable[name](...) end
end })
exports = setmetatable({}, {
    __call = function(_, name, fn) Fake.exportsTable[name] = fn end,
    __index = function() return resourceProxy end,
})

Fake.commands = {}
function RegisterCommand(name, fn) Fake.commands[name] = fn end
function Fake.run(src, line)
    local args = {}
    for w in line:gmatch('%S+') do args[#args + 1] = w end
    local name = table.remove(args, 1)
    source = src
    Fake.commands[name](src, args, line)
end
function GetPlayerName(src) return Fake.identifiers[src] and 'Jogador' or nil end
function GetPlayerEndpoint() return '127.0.0.1' end
function SetEntityCoords() end
function Fake.notices(src)
    local out = {}
    for _, e in ipairs(Fake.clientEvents) do
        if e.name == 'ox_lib:notify' and e.src == src then out[#out + 1] = e.args[1].description end
    end
    return out
end

lib = { callback = { register = function(name, fn) Fake.callbacks[name] = fn end } }
