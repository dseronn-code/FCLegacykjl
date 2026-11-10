-- Gera packages/shared/permissions.json a partir da config do spc_core (fonte única de permissões).
-- Uso (a partir de sp-capital-rp/): lua5.4 infra/scripts/gen-permissions.lua
local base = 'game/resources/[spc-core]/spc_core/shared/'
dofile(base .. 'config.lua')
dofile(base .. 'permissions_core.lua')
local cfg = SPC.Config
local effective = SPC.PermissionsCore.build(cfg.StaffRoles, cfg.RolePermissions)

local function str(s) return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
local lines = { '{', '  "roles": [' .. table.concat((function()
    local t = {} for i, r in ipairs(cfg.StaffRoles) do t[i] = str(r) end return t end)(), ', ') .. '],', '  "effective": {' }
for i, role in ipairs(cfg.StaffRoles) do
    local perms = {}
    for p in pairs(effective[role]) do perms[#perms + 1] = p end
    table.sort(perms)
    for k, p in ipairs(perms) do perms[k] = str(p) end
    lines[#lines + 1] = ('    %s: [%s]%s'):format(str(role), table.concat(perms, ', '), i < #cfg.StaffRoles and ',' or '')
end
lines[#lines + 1] = '  }'
lines[#lines + 1] = '}'
local f = assert(io.open('packages/shared/permissions.json', 'w'))
f:write(table.concat(lines, '\n') .. '\n')
f:close()
print('packages/shared/permissions.json gerado')
