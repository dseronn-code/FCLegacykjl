-- Adaptador fino sobre o oxmysql. Único arquivo que conhece a API do driver.
SPC.DB = {}
local DB = SPC.DB

local bindNulls = SPC.Util.bindNulls

-- Todas as chamadas passam por bindNulls: parâmetros nil viram NULL sem deslocar os demais.
local function wrap(fn)
    return function(sql, params) return fn(bindNulls(sql, params)) end
end

DB.query = wrap(MySQL.query.await)   -- linhas
DB.single = wrap(MySQL.single.await) -- primeira linha ou nil
DB.scalar = wrap(MySQL.scalar.await) -- primeiro valor ou nil
DB.insert = wrap(MySQL.insert.await) -- insertId
DB.update = wrap(MySQL.update.await) -- affectedRows

--- Executa `fn(query)` numa transação. `fn` retorna true para COMMIT e false para ROLLBACK.
-- Erros de SQL dentro de `fn` causam ROLLBACK. Retorna true se houve COMMIT.
-- `query(sql, params)` retorna linhas (SELECT) ou { affectedRows, insertId } (escrita).
function DB.transaction(fn)
    return MySQL.startTransaction(function(query)
        return fn(function(sql, params) return query(bindNulls(sql, params)) end)
    end) == true
end

--- Converte valores numéricos do driver (número ou string de BIGINT) para inteiro Lua.
function DB.int(v)
    if v == nil then return nil end
    return math.tointeger(tonumber(v))
end

--- "?, ?, ?" para cláusulas IN com parâmetros.
function DB.placeholders(n)
    return string.rep('?', n, ', ')
end
