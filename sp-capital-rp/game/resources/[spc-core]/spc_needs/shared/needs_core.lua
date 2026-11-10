-- Regras puras de necessidades (testadas em tests/lua/test_needs.lua)
SPCNeeds = SPCNeeds or {}
local N = {}

N.Defaults = { hunger = 100, thirst = 100, stress = 0 }
N.DecayPerMinute = { hunger = 0.55, thirst = 0.83, stress = 1.0 } -- stress diminui quando calmo
N.StarveDamage = 5
N.LowWarning = 15

-- Efeitos dos itens: o cliente nunca envia números, só o servidor aplica esta tabela
N.Items = {
    water = { thirst = 35 },
    soda = { hunger = 5, thirst = 25, stress = -2 },
    coffee = { thirst = 10, stress = -5 },
    sandwich = { hunger = 30 },
    pastel = { hunger = 35, thirst = -5, stress = -3 },
}

local function clamp(v) return math.max(0, math.min(100, v)) end

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

--- Normaliza um status vindo do banco/state bag (valores ausentes ou inválidos viram o padrão).
function N.normalize(status)
    local out = {}
    for k, def in pairs(N.Defaults) do
        local v = type(status) == 'table' and tonumber(status[k]) or nil
        out[k] = v and clamp(v) or def
    end
    return out
end

--- Aplica `minutes` de decaimento. `factor` 0 = pausado, 0.5 = preso, 1 = normal.
function N.decay(status, minutes, factor)
    local s = N.normalize(status)
    local f = (factor or 1) * minutes
    s.hunger = round2(clamp(s.hunger - N.DecayPerMinute.hunger * f))
    s.thirst = round2(clamp(s.thirst - N.DecayPerMinute.thirst * f))
    s.stress = round2(clamp(s.stress - N.DecayPerMinute.stress * minutes)) -- estresse cai mesmo pausado
    return s
end

--- Aplica o efeito de um item. Retorna novo status ou nil se o item não é consumível.
function N.applyItem(status, itemName)
    local fx = N.Items[itemName]
    if not fx then return nil end
    local s = N.normalize(status)
    for k, v in pairs(fx) do s[k] = clamp(s[k] + v) end
    return s
end

--- Dano por fome/sede zerada.
function N.starveDamage(status)
    local s = N.normalize(status)
    return (s.hunger <= 0 or s.thirst <= 0) and N.StarveDamage or 0
end

function N.isLow(status)
    local s = N.normalize(status)
    return s.hunger < N.LowWarning or s.thirst < N.LowWarning
end

SPCNeeds.Core = N
return N
