-- Comandos externos vindos do painel/bot via spc_bridge.
-- IMPORTANTE: apenas AddEventHandler (nunca RegisterNetEvent) — clientes não podem disparar estes eventos.
-- Spec: docs/sp-capital-rp/specs/spc_core.md §7 · docs/sp-capital-rp/specs/logs-e-bridge.md
local DB = SPC.DB

local function ack(id, ok, result)
    if GetResourceState('spc_bridge') == 'started' then exports.spc_bridge:Ack(id, ok, result) end
end

local function findSource(payload)
    if type(payload) ~= 'table' then return nil end
    if type(payload.citizenid) == 'string' then return SPC.Players.sourceByCitizen(payload.citizenid) end
    if type(payload.license) == 'string' then
        for src, s in pairs(SPC.Players.bySource) do
            if s.license == payload.license then return src end
        end
    end
end

AddEventHandler('spc:cmd:player.kick', function(id, payload, actor)
    local src = findSource(payload)
    if not src then return ack(id, false, 'not_online') end
    local reason = type(payload.reason) == 'string' and payload.reason:sub(1, 200) or 'Removido pela staff'
    SPC.Log('admin', 'kick', { src = src, actor = actor, reason = reason })
    DropPlayer(src, 'Você foi removido da cidade: ' .. reason)
    ack(id, true)
end)

AddEventHandler('spc:cmd:account.refresh', function(id, payload, actor)
    if type(payload) ~= 'table' or type(payload.discordId) ~= 'string' then return ack(id, false, 'invalid_payload') end
    local src, session = SPC.Players.byDiscord(payload.discordId)
    if not src then return ack(id, true, 'not_online') end

    local ids = { license = session.license, discord = 'discord:' .. session.discordId }
    local acc, reason = SPC.checkAccount(ids)
    if not acc then
        SPC.Log('admin', 'account_refresh_drop', { src = src, actor = actor, reason = reason })
        DropPlayer(src, 'Sua conta foi atualizada pela staff (' .. tostring(reason) .. '). Verifique o Discord.')
        return ack(id, true, 'dropped')
    end
    session.staffRole = (DB.int(acc.staff_active) == 1) and acc.staff_role or nil
    session.charSlots = DB.int(acc.char_slots)
    ack(id, true, 'refreshed')
end)
