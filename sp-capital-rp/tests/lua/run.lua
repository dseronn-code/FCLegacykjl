-- Executor de testes mínimo (sem dependências). Uso: lua5.4 tests/lua/run.lua  (a partir de sp-capital-rp/)
local ROOT = 'game/resources/[spc-core]/spc_core/shared/'
for _, f in ipairs({ 'config.lua', 'util.lua', 'identity.lua', 'ledger_core.lua', 'permissions_core.lua' }) do
    dofile(ROOT .. f)
end

local passed, failed, current = 0, 0, ''
function describe(name, fn) current = name; fn() end
function it(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else
        failed = failed + 1
        print(('FALHOU  %s › %s\n        %s'):format(current, name, tostring(err)))
    end
end
function eq(a, b, msg)
    if a ~= b then error((msg or 'esperado igual') .. (': %s ~= %s'):format(tostring(a), tostring(b)), 2) end
end
function truthy(v, msg) if not v then error(msg or 'esperado verdadeiro', 2) end end

for _, f in ipairs({ 'test_identity.lua', 'test_util.lua', 'test_ledger_core.lua', 'test_permissions.lua' }) do
    dofile('tests/lua/' .. f)
end

print(('%d passaram, %d falharam'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
