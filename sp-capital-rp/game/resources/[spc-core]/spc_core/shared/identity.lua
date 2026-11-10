-- Geração e validação de dados de identidade do personagem (funções puras).
-- Spec: docs/sp-capital-rp/specs/spc_core.md §4.2
SPC = SPC or {}
local Identity = {}

local BASE36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'

local function digits(rand, n)
    local t = {}
    for i = 1, n do t[i] = tostring(rand(0, 9)) end
    return t
end

--- `SPC` + 5 caracteres base36 (total 8, cabe em CHAR(8)).
function Identity.citizenId(rand)
    local out = { 'SPC' }
    for i = 1, 5 do
        local k = rand(1, #BASE36)
        out[#out + 1] = BASE36:sub(k, k)
    end
    return table.concat(out)
end

-- Dígitos verificadores pela regra real da Receita (usado para garantir que NÃO geramos CPF real válido).
local function realCheckDigits(d)
    local sum = 0
    for i = 1, 9 do sum = sum + tonumber(d[i]) * (11 - i) end
    local r = sum % 11
    local dv1 = r < 2 and 0 or 11 - r
    sum = 0
    for i = 1, 9 do sum = sum + tonumber(d[i]) * (12 - i) end
    sum = sum + dv1 * 2
    r = sum % 11
    local dv2 = r < 2 and 0 or 11 - r
    return dv1, dv2
end

-- Regra do jogo: DV1 = (DV1 real + 1) mod 10; DV2 calculado normalmente sobre o DV1 do jogo.
local function gameCheckDigits(d)
    local dv1 = (realCheckDigits(d) + 1) % 10
    local sum = 0
    for i = 1, 9 do sum = sum + tonumber(d[i]) * (12 - i) end
    sum = sum + dv1 * 2
    local r = sum % 11
    local dv2 = r < 2 and 0 or 11 - r
    return dv1, dv2
end

local function formatCpf(d, dv1, dv2)
    return string.format('%s%s%s.%s%s%s.%s%s%s-%d%d', d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], dv1, dv2)
end

local function parseCpf(cpf)
    if type(cpf) ~= 'string' or not cpf:match('^%d%d%d%.%d%d%d%.%d%d%d%-%d%d$') then return nil end
    local d = {}
    for c in cpf:gmatch('%d') do d[#d + 1] = c end
    return d
end

--- CPF fictício: formato válido, dígitos verificadores inválidos pela regra real.
function Identity.cpf(rand)
    local d
    repeat
        d = digits(rand, 9)
        local same = true
        for i = 2, 9 do if d[i] ~= d[1] then same = false break end end
    until not same
    return formatCpf(d, gameCheckDigits(d))
end

function Identity.isGameCpf(cpf)
    local d = parseCpf(cpf)
    if not d then return false end
    local dv1, dv2 = gameCheckDigits(d)
    return tonumber(d[10]) == dv1 and tonumber(d[11]) == dv2
end

function Identity.isRealCpf(cpf)
    local d = parseCpf(cpf)
    if not d then return false end
    local dv1, dv2 = realCheckDigits(d)
    return tonumber(d[10]) == dv1 and tonumber(d[11]) == dv2
end

function Identity.rg(rand)
    local d = digits(rand, 9)
    return string.format('%s%s.%s%s%s.%s%s%s-%s', table.unpack(d))
end

function Identity.phone(rand)
    local d = digits(rand, 8)
    return string.format('(11) 9%s%s%s%s-%s%s%s%s', table.unpack(d))
end

-- Mapa simples de letras acentuadas (UTF-8) → ASCII, para comparar com a lista bloqueada.
local ACCENTS = {
    ['á'] = 'a', ['à'] = 'a', ['â'] = 'a', ['ã'] = 'a', ['ä'] = 'a', ['é'] = 'e', ['ê'] = 'e', ['è'] = 'e',
    ['ë'] = 'e', ['í'] = 'i', ['ì'] = 'i', ['î'] = 'i', ['ï'] = 'i', ['ó'] = 'o', ['ò'] = 'o', ['ô'] = 'o',
    ['õ'] = 'o', ['ö'] = 'o', ['ú'] = 'u', ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ç'] = 'c', ['ñ'] = 'n',
    ['Á'] = 'a', ['À'] = 'a', ['Â'] = 'a', ['Ã'] = 'a', ['Ä'] = 'a', ['É'] = 'e', ['Ê'] = 'e', ['È'] = 'e',
    ['Ë'] = 'e', ['Í'] = 'i', ['Ì'] = 'i', ['Î'] = 'i', ['Ï'] = 'i', ['Ó'] = 'o', ['Ò'] = 'o', ['Ô'] = 'o',
    ['Õ'] = 'o', ['Ö'] = 'o', ['Ú'] = 'u', ['Ù'] = 'u', ['Û'] = 'u', ['Ü'] = 'u', ['Ç'] = 'c', ['Ñ'] = 'n',
}

-- Pares maiúscula/minúscula para normalizar capitalização com acentos.
local UPPER_TO_LOWER = {
    ['Á'] = 'á', ['À'] = 'à', ['Â'] = 'â', ['Ã'] = 'ã', ['Ä'] = 'ä', ['É'] = 'é', ['Ê'] = 'ê', ['È'] = 'è',
    ['Ë'] = 'ë', ['Í'] = 'í', ['Ì'] = 'ì', ['Î'] = 'î', ['Ï'] = 'ï', ['Ó'] = 'ó', ['Ò'] = 'ò', ['Ô'] = 'ô',
    ['Õ'] = 'õ', ['Ö'] = 'ö', ['Ú'] = 'ú', ['Ù'] = 'ù', ['Û'] = 'û', ['Ü'] = 'ü', ['Ç'] = 'ç', ['Ñ'] = 'ñ',
}
local LOWER_TO_UPPER = {}
for u, l in pairs(UPPER_TO_LOWER) do LOWER_TO_UPPER[l] = u end

-- Divide uma string UTF-8 em caracteres. Retorna nil se houver byte inválido.
local function utf8chars(s)
    local out = {}
    for _, cp in utf8.codes(s) do out[#out + 1] = utf8.char(cp) end
    return out
end

local function isAllowedChar(c)
    if c:match('^[A-Za-z]$') or c == ' ' or c == '-' or c == "'" then return true end
    return ACCENTS[c] ~= nil
end

local function lower(c) return UPPER_TO_LOWER[c] or c:lower() end
local function upper(c) return LOWER_TO_UPPER[c] or c:upper() end

function Identity.foldAscii(s)
    local ok, chars = pcall(utf8chars, s)
    if not ok then return nil end
    for i, c in ipairs(chars) do chars[i] = ACCENTS[c] or c:lower() end
    return table.concat(chars)
end

--- Valida e normaliza um nome ("joão da SILVA" → "João Da Silva"). Retorna nome ou nil, erro.
function Identity.normalizeName(name, blocked)
    if type(name) ~= 'string' then return nil, 'invalid_name' end
    name = name:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if not utf8.len(name) then return nil, 'invalid_name' end
    local chars = utf8chars(name)
    if #chars < 2 or #chars > 20 then return nil, 'invalid_name_length' end
    local letters = 0
    for _, c in ipairs(chars) do
        if not isAllowedChar(c) then return nil, 'invalid_name_chars' end
        if c ~= ' ' and c ~= '-' and c ~= "'" then letters = letters + 1 end
    end
    if letters < 2 then return nil, 'invalid_name_chars' end

    local folded = Identity.foldAscii(name)
    for _, word in ipairs(blocked or {}) do
        if folded:find(word, 1, true) then return nil, 'blocked_name' end
    end

    local startWord = true
    for i, c in ipairs(chars) do
        if c == ' ' or c == '-' or c == "'" then
            startWord = true
        else
            chars[i] = startWord and upper(c) or lower(c)
            startWord = false
        end
    end
    return table.concat(chars)
end

local DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

--- Valida 'AAAA-MM-DD' e a idade em relação a `today` ({year, month, day}).
function Identity.validateBirthdate(s, today, minAge, maxAge)
    if type(s) ~= 'string' then return false, 'invalid_birthdate' end
    local y, m, d = s:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not y then return false, 'invalid_birthdate' end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m < 1 or m > 12 then return false, 'invalid_birthdate' end
    local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
    local maxDay = (m == 2 and leap) and 29 or DAYS[m]
    if d < 1 or d > maxDay then return false, 'invalid_birthdate' end
    local age = today.year - y
    if today.month < m or (today.month == m and today.day < d) then age = age - 1 end
    if age < minAge or age > maxAge then return false, 'invalid_age' end
    return true
end

local GENDERS = { m = true, f = true, x = true }
function Identity.isValidGender(g) return GENDERS[g] == true end

SPC.Identity = Identity
return Identity
