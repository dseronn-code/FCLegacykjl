-- Ponte do ox_inventory para o spc_core (convar: setr inventory:framework "spc")
-- Spec: docs/sp-capital-rp/specs/inventario.md
-- Instalada por sp-capital-rp/infra/scripts/install-overlays.sh — não editar a cópia dentro do ox_inventory.
if not lib.checkDependency('spc_core', '0.1.0', true) then return end

local Inventory = require 'modules.inventory.server'
local db = require 'modules.mysql.server'

db.setup({
    user = { table = 'characters', col = 'id' },
    vehicle = { table = 'vehicles', col = 'id' },
})

local STARTER = {
    { 'money', 500 }, { 'phone', 1 }, { 'water', 2 }, { 'sandwich', 2 },
}

local function giveStarterItems(src, c)
    -- Entrega única: só o UPDATE que mudou 1 linha entrega o kit (seguro contra reconexão e corrida)
    local changed = MySQL.update.await('UPDATE characters SET starter_items_at = NOW() WHERE id = ? AND starter_items_at IS NULL', { c.id })
    if changed ~= 1 then return end
    for _, it in ipairs(STARTER) do Inventory.AddItem(src, it[1], it[2]) end
    Inventory.AddItem(src, 'id_card', 1, {
        name = c.firstName .. ' ' .. c.lastName, rg = c.rg, cpf = c.cpf, birthdate = c.birthdate,
        description = ('RG %s · CPF %s · Nasc. %s'):format(c.rg, c.cpf, c.birthdate),
    })
end

local function loadPlayer(src)
    local p = exports.spc_core:GetPlayer(src)
    if not p or not p.character then return end
    local c = p.character
    server.setPlayerInventory({
        source = src,
        identifier = c.id,
        name = c.firstName .. ' ' .. c.lastName,
        groups = exports.spc_core:GetGroups(src) or {},
        sex = c.gender,
        dateofbirth = c.birthdate,
    })
    giveStarterItems(src, c)
end

AddEventHandler('spc_core:server:characterLoaded', function(src) loadPlayer(src) end)
AddEventHandler('spc_core:server:playerDropped', function(src) server.playerDropped(src) end)

AddEventHandler('spc_core:server:groupsChanged', function(src, groups)
    local inv = Inventory(src)
    if inv and inv.player then inv.player.groups = groups or {} end
end)

-- Reinício do ox_inventory com jogadores online
SetTimeout(500, function()
    for _, id in ipairs(GetPlayers()) do loadPlayer(tonumber(id)) end
end)

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source = player.source,
        name = player.name,
        groups = player.groups or {},
        sex = player.sex,
        dateofbirth = player.dateofbirth,
    }
end

-- Licenças (CNH, porte) chegarão com a spec do DETRAN
---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense() return false end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss() return false end
