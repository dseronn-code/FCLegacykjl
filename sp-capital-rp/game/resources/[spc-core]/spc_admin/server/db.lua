-- Acesso ao banco com nil → NULL (mesmo helper do spc_core: arrays Lua com buraco perdem posições)
local bind = SPC.Util.bindNulls
DB = {
    insert = function(sql, p) return MySQL.insert.await(bind(sql, p)) end,
    update = function(sql, p) return MySQL.update.await(bind(sql, p)) end,
    scalar = function(sql, p) return MySQL.scalar.await(bind(sql, p)) end,
    transaction = function(fn)
        return MySQL.startTransaction(function(query)
            return fn(function(sql, p) return query(bind(sql, p)) end)
        end) == true
    end,
}
