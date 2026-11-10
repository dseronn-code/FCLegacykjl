-- Ponte cliente do ox_inventory para o spc_core
-- Grupos (empregos/facções) chegam pelo state bag `groups`, escrito apenas pelo servidor.
local function syncGroups(groups) client.setPlayerData('groups', groups or {}) end

AddStateBagChangeHandler('groups', ('player:%s'):format(cache.serverId), function(_, _, value)
    syncGroups(value)
end)

SetTimeout(500, function() syncGroups(LocalPlayer.state.groups) end)
