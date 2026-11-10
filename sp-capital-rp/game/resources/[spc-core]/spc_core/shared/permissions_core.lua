-- Resolução pura de permissões por papel de staff (com herança).
-- Spec: docs/sp-capital-rp/specs/spc_core.md §5
SPC = SPC or {}
local PermissionsCore = {}

--- Constrói mapa papel → conjunto de permissões efetivas (herdando os papéis inferiores).
function PermissionsCore.build(roles, rolePermissions)
    local effective, acc = {}, {}
    for _, role in ipairs(roles) do
        for _, perm in ipairs(rolePermissions[role] or {}) do acc[perm] = true end
        local copy = {}
        for p in pairs(acc) do copy[p] = true end
        effective[role] = copy
    end
    return effective
end

--- `perms` é o conjunto efetivo do papel. Aceita curinga total '*' e por prefixo ('players.*').
function PermissionsCore.has(perms, perm)
    if not perms or type(perm) ~= 'string' then return false end
    if perms['*'] or perms[perm] then return true end
    local prefix = perm:match('^([^.]+)%.')
    return prefix ~= nil and perms[prefix .. '.*'] == true
end

SPC.PermissionsCore = PermissionsCore
return PermissionsCore
