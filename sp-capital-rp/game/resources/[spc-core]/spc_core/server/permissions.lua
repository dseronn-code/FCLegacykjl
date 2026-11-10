local PermissionsCore = SPC.PermissionsCore
local effective = PermissionsCore.build(SPC.Config.StaffRoles, SPC.Config.RolePermissions)
local providers = {}

SPC.Permissions = {}

local rank = {}
for i, role in ipairs(SPC.Config.StaffRoles) do rank[role] = i end

--- Posição do papel na hierarquia (0 = não é staff).
function SPC.Permissions.rank(role) return rank[role] or 0 end

--- true se `a` tem papel estritamente superior a `b` (console sempre supera).
function SPC.Permissions.outranks(a, b)
    if a == 0 then return true end
    local sa, sb = SPC.Players.get(a), SPC.Players.get(b)
    return SPC.Permissions.rank(sa and sa.staffRole) > SPC.Permissions.rank(sb and sb.staffRole)
end

--- Provedores externos (empregos, facções) respondem true/false/nil para permissões próprias.
function SPC.Permissions.registerProvider(fn, resource)
    providers[#providers + 1] = { fn = fn, resource = resource }
end

function SPC.Permissions.has(src, perm)
    if src == 0 then return true end -- console do servidor
    local s = SPC.Players.get(src)
    if not s then return false end
    if s.staffRole and PermissionsCore.has(effective[s.staffRole], perm) then return true end
    for _, p in ipairs(providers) do
        local ok, res = pcall(p.fn, src, perm)
        if ok and res == true then return true end
    end
    return false
end

-- Remove provedores de recursos que pararam (evita chamar função de recurso morto)
AddEventHandler('onResourceStop', function(resource)
    for i = #providers, 1, -1 do
        if providers[i].resource == resource then table.remove(providers, i) end
    end
end)
