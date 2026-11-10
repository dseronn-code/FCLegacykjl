-- Regras puras do spc_admin (testadas em tests/lua/test_admin.lua)
SPCAdmin = SPCAdmin or {}
local A = {}

A.MaxHours = 8760   -- 1 ano
A.TempLimitHours = 72 -- limite de quem só tem bans.temp
A.WarnDays = 60

--- '24' → 24 · 'perm' → 'perm' · inválido → nil, erro
function A.parseDuration(s)
    if s == 'perm' or s == 'permanente' then return 'perm' end
    local n = tonumber(s)
    if not n or n ~= math.floor(n) or n < 1 or n > A.MaxHours then return nil, 'invalid_duration' end
    return math.tointeger(n)
end

--- Pode aplicar esse ban com as permissões que tem?
function A.canBan(duration, hasFull, hasTemp)
    if hasFull then return true end
    if not hasTemp then return false, 'no_permission' end
    if duration == 'perm' or duration > A.TempLimitHours then return false, 'temp_limit' end
    return true
end

--- Junta os argumentos restantes num motivo; mínimo de 5 caracteres, máximo 255.
function A.reason(args, from)
    local parts = {}
    for i = from, #args do parts[#parts + 1] = args[i] end
    local r = table.concat(parts, ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if utf8.len(r) == nil or #r < 5 then return nil, 'reason_required' end
    return r:sub(1, 255)
end

function A.parseTarget(s)
    local n = tonumber(s)
    if not n or n < 1 or n ~= math.floor(n) then return nil end
    return math.tointeger(n)
end

function A.parsePoints(s)
    local n = tonumber(s)
    if not n or n < 1 or n > 3 or n ~= math.floor(n) then return nil end
    return math.tointeger(n)
end

SPCAdmin.Core = A
return A
