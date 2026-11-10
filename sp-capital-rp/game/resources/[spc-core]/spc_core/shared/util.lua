-- Utilitários puros: rate limit, ULID, formatação de dinheiro.
SPC = SPC or {}

---------------------------------------------------------------------------
-- RateLimit: no máximo 1 chamada por `intervalMs` por chave.
---------------------------------------------------------------------------
local RateLimit = {}
RateLimit.__index = RateLimit

function RateLimit.new()
    return setmetatable({ last = {} }, RateLimit)
end

function RateLimit:allow(key, intervalMs, nowMs)
    local prev = self.last[key]
    if prev and nowMs - prev < intervalMs then return false end
    self.last[key] = nowMs
    return true
end

--- Remove todas as chaves com o prefixo (ex.: ao desconectar o jogador).
function RateLimit:clear(prefix)
    for k in pairs(self.last) do
        if k:sub(1, #prefix) == prefix then self.last[k] = nil end
    end
end

---------------------------------------------------------------------------
-- ULID (26 caracteres Crockford base32): 48 bits de tempo em ms + 80 bits aleatórios.
---------------------------------------------------------------------------
local CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

local function ulid(nowMs, rand)
    local out = {}
    local t = math.floor(nowMs)
    for i = 10, 1, -1 do
        local k = t % 32
        out[i] = CROCKFORD:sub(k + 1, k + 1)
        t = t // 32
    end
    for i = 11, 26 do
        local k = rand(0, 31)
        out[i] = CROCKFORD:sub(k + 1, k + 1)
    end
    return table.concat(out)
end

local function isUlid(s)
    return type(s) == 'string' and #s == 26 and s:match('^[0-9A-HJKMNP-TV-Z]+$') ~= nil
end

---------------------------------------------------------------------------
-- Dinheiro (centavos → "R$ 1.234,56")
---------------------------------------------------------------------------
local function formatBRL(cents)
    cents = math.tointeger(cents) or 0
    local neg = cents < 0
    if neg then cents = -cents end
    local reais, cent = cents // 100, cents % 100
    local s = tostring(reais):reverse():gsub('(%d%d%d)', '%1.'):reverse()
    if s:sub(1, 1) == '.' then s = s:sub(2) end
    return string.format('%sR$ %s,%02d', neg and '-' or '', s, cent)
end

---------------------------------------------------------------------------
-- bindNulls: troca cada `?` cujo parâmetro é nil por NULL literal e compacta os parâmetros.
-- Necessário porque arrays Lua com buracos (nil) perdem posições ao serem serializados para o driver.
-- Premissa: o SQL não contém '?' dentro de literais de texto (regra do projeto).
---------------------------------------------------------------------------
local function bindNulls(sql, params)
    if params == nil then return sql, nil end
    local i, n, out = 0, 0, {}
    local bound = sql:gsub('%?', function()
        i = i + 1
        local v = params[i]
        if v == nil then return 'NULL' end
        n = n + 1
        out[n] = v
        return '?'
    end)
    return bound, out
end

SPC.RateLimit = RateLimit
SPC.Util = { ulid = ulid, isUlid = isUlid, formatBRL = formatBRL, bindNulls = bindNulls }
return SPC.Util
