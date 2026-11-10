-- Regras puras do banco (testadas em tests/lua/test_bank.lua)
SPCBank = SPCBank or {}
local B = {}

--- Valor em reais inteiro e positivo, até `max`. Retorna inteiro ou nil, erro.
function B.parseAmount(v, max)
    if type(v) ~= 'number' then v = tonumber(v) end
    if not v or v ~= math.floor(v) or v < 1 then return nil, 'invalid_amount' end
    v = math.tointeger(v)
    if max and v > max then return nil, 'over_limit' end
    return v
end

local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
B.distance = dist

--- Agência mais próxima dentro do raio, ou nil.
function B.nearBranch(pos, branches, maxDist)
    for _, br in ipairs(branches) do
        if dist(pos, br.coords) <= maxDist then return br end
    end
end

--- Imposto do PIX em reais (1% acima do limite, arredondado para baixo, mínimo 1 quando aplicável).
function B.pixTax(amount, threshold, percent)
    if amount <= threshold then return 0 end
    return math.max(1, (amount * percent) // 100)
end

--- Movimentos do ledger (centavos) para um PIX, incluindo imposto na mesma transação.
function B.pixLegs(fromId, toId, amount, limits, ref)
    local legs = { { from = { id = fromId }, to = { id = toId }, amount = amount * 100, reason = 'pix.send', ref = ref } }
    local tax = B.pixTax(amount, limits.PixTaxThreshold, limits.PixTaxPercent)
    if tax > 0 then
        legs[2] = { from = { id = fromId }, to = { system = 'SINK_TAX' }, amount = tax * 100, reason = 'tax.transfer', ref = ref }
    end
    return legs, tax
end

--- Telefone no formato do jogo: (11) 9XXXX-XXXX. Aceita só dígitos e normaliza.
function B.normalizePhone(s)
    if type(s) ~= 'string' then return nil end
    local d = s:gsub('%D', '')
    if #d == 11 and d:sub(1, 3) == '119' then
        return ('(%s) %s-%s'):format(d:sub(1, 2), d:sub(3, 7), d:sub(8, 11))
    end
end

SPCBank.Core = B
return B
