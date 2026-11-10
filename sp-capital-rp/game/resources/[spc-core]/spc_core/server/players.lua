-- Sessões em memória: source → sessão. Uma sessão nasce na entrada e morre no drop.
SPC.Players = { bySource = {}, byCitizen = {} }
local Players = SPC.Players

-- sessão = { source, accountId, license, discordId, charSlots, staffRole, joinedAt, character = nil | {...} }
function Players.add(session)
    Players.bySource[session.source] = session
end

function Players.get(src)
    return Players.bySource[src]
end

function Players.setCharacter(src, character)
    local s = Players.bySource[src]
    if not s then return end
    s.character = character
    Players.byCitizen[character.citizenid] = src
end

function Players.remove(src)
    local s = Players.bySource[src]
    if not s then return nil end
    if s.character then Players.byCitizen[s.character.citizenid] = nil end
    Players.bySource[src] = nil
    return s
end

function Players.sourceByCitizen(citizenid)
    return Players.byCitizen[citizenid]
end

function Players.byDiscord(discordId)
    for src, s in pairs(Players.bySource) do
        if s.discordId == discordId then return src, s end
    end
end

--- Cópia somente leitura para outros recursos (nunca expor a tabela interna).
function Players.snapshot(src)
    local s = Players.bySource[src]
    if not s then return nil end
    local c = s.character
    return {
        source = s.source, accountId = s.accountId, license = s.license, discordId = s.discordId,
        staffRole = s.staffRole,
        character = c and {
            id = c.id, citizenid = c.citizenid, firstName = c.firstName, lastName = c.lastName,
            birthdate = c.birthdate, gender = c.gender, cpf = c.cpf, rg = c.rg, phone = c.phone,
            bankAccountId = c.bankAccountId,
        } or nil,
    }
end

-- Rate limit compartilhado pelos callbacks
SPC.Limiter = SPC.RateLimit.new()

function SPC.allow(src, name)
    return SPC.Limiter:allow(src .. ':' .. name, SPC.Config.RateLimits[name] or 1000, GetGameTimer())
end
