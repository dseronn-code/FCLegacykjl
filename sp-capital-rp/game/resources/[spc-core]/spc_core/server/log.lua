-- Encaminha logs para o spc_logs se estiver rodando (o core não depende dele para funcionar).
function SPC.Log(category, action, data, level)
    if GetResourceState('spc_logs') == 'started' then
        exports.spc_logs:Log(category, action, data, level)
    elseif level == 'alert' or level == 'warn' then
        print(('[spc_core] %s %s.%s %s'):format(level, category, action, json.encode(data or {})))
    end
end
