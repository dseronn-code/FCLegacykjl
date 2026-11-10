-- Comandos de staff. Spec: docs/sp-capital-rp/specs/spc_admin.md
-- Este recurso é o dono da escrita em bans, ban_identifiers, warnings e audit_log (o spc_core só lê bans).
local A = SPCAdmin.Core
local core = exports.spc_core
local staffMode = {} -- src → true

local MESSAGES = {
    no_permission = 'Você não tem permissão para isso.',
    staff_mode = 'Ative o modo staff (/staff) primeiro.',
    invalid_target = 'Jogador não encontrado (use o ID do servidor).',
    reason_required = 'Informe um motivo (mín. 5 caracteres).',
    invalid_duration = 'Duração inválida: use horas (1–8760) ou "perm".',
    temp_limit = 'Seu cargo só permite bans de até 72 horas.',
    outranked = 'Você não pode aplicar isso em staff de cargo igual ou superior.',
    invalid_points = 'Pontos devem ser 1, 2 ou 3.',
    not_found = 'Registro não encontrado ou já revogado.',
}

local function notify(src, msg, kind)
    if src == 0 then print('[spc_admin] ' .. msg) return end
    TriggerClientEvent('ox_lib:notify', src, { title = 'Staff', description = msg, type = kind or 'inform' })
end

local function fail(src, code) notify(src, MESSAGES[code] or code, 'error') end

local function log(action, data, level)
    if GetResourceState('spc_logs') == 'started' then exports.spc_logs:Log('admin', action, data, level) end
end

local function accountIdOf(src)
    if src == 0 then return nil end
    local p = core:GetPlayer(src)
    return p and p.accountId or nil
end

local function actorOf(src) return src == 0 and 'console' or ('staff:' .. tostring(accountIdOf(src))) end

local function audit(staffSrc, action, target, before, after)
    DB.insert('INSERT INTO audit_log (staff_account_id, action, target, before_data, after_data, ip) VALUES (?, ?, ?, ?, ?, ?)', {
        accountIdOf(staffSrc), action, target,
        before and json.encode(before) or nil, after and json.encode(after) or nil,
        staffSrc ~= 0 and GetPlayerEndpoint(staffSrc) or nil,
    })
end

local function allowed(src, perm)
    if core:HasPermission(src, perm) then return true end
    log('permission_denied', { src = src, perm = perm }, 'warn')
    fail(src, 'no_permission')
    return false
end

local function target(src, arg)
    local t = A.parseTarget(arg)
    if not t or not GetPlayerName(t) then fail(src, 'invalid_target') return nil end
    return t
end

local function inStaffMode(src)
    if src == 0 or staffMode[src] then return true end
    fail(src, 'staff_mode')
    return false
end

--- Identificadores + tokens de hardware do jogador para o ban.
local function allIdentifiers(src)
    local list = {}
    for _, t in ipairs({ 'license', 'license2', 'discord', 'fivem', 'steam' }) do
        local v = GetPlayerIdentifierByType(src, t)
        if v then list[#list + 1] = v end
    end
    for i = 0, GetNumPlayerTokens(src) - 1 do
        local tok = GetPlayerToken(src, i)
        if tok then list[#list + 1] = 'token:' .. tok end
    end
    return list
end

--- Ban: grava ban + identificadores numa transação e derruba. Exposto para a API/bridge futuramente.
local function ban(staffSrc, targetSrc, duration, reason)
    local targetAccount = accountIdOf(targetSrc)
    local ids = allIdentifiers(targetSrc)
    local hours = duration ~= 'perm' and duration or nil
    local banId

    local ok = DB.transaction(function(query)
        local res = query('INSERT INTO bans (account_id, reason, staff_account_id, expires_at) VALUES (?, ?, ?, IF(? = 0, NULL, NOW() + INTERVAL ? HOUR))',
            { targetAccount, reason, accountIdOf(staffSrc), hours or 0, hours or 0 })
        banId = res.insertId
        for _, id in ipairs(ids) do
            query('INSERT IGNORE INTO ban_identifiers (ban_id, identifier) VALUES (?, ?)', { banId, id })
        end
        return true
    end)
    if not ok then notify(staffSrc, 'Erro ao gravar o ban.', 'error') return end

    local info = { banId = banId, hours = hours or 'perm', reason = reason, identifiers = #ids }
    audit(staffSrc, 'ban', 'account:' .. tostring(targetAccount), nil, info)
    log('ban', { src = targetSrc, actor = actorOf(staffSrc), banId = banId, hours = hours or 'perm', reason = reason }, 'warn')
    DropPlayer(targetSrc, ('Você foi banido da SP Capital.\nMotivo: %s\nDuração: %s\nID do ban: #%d')
        :format(reason, hours and (hours .. ' hora(s)') or 'permanente', banId))
    notify(staffSrc, ('Ban #%d aplicado.'):format(banId), 'success')
    return banId
end

SPCAdmin.ban = ban -- usado pelos testes de integração

local function command(name, fn)
    RegisterCommand(name, function(src, args) fn(src, args or {}) end, false)
end

command('staff', function(src)
    if src == 0 or not allowed(src, 'players.read') then return end
    staffMode[src] = not staffMode[src] or nil
    Player(src).state:set('staffMode', staffMode[src] == true, true)
    log(staffMode[src] and 'staff_mode_on' or 'staff_mode_off', { src = src })
    notify(src, staffMode[src] and 'Modo staff ATIVADO.' or 'Modo staff desativado.', 'inform')
    if not staffMode[src] then TriggerClientEvent('spc_admin:client:setNoclip', src, false) end
end)

command('kick', function(src, args)
    if not allowed(src, 'players.kick') then return end
    local t = target(src, args[1]); if not t then return end
    local tp = core:GetPlayer(t)
    if tp and tp.staffRole and not core:Outranks(src, t) then return fail(src, 'outranked') end
    local reason, err = A.reason(args, 2); if not reason then return fail(src, err) end
    audit(src, 'kick', 'account:' .. tostring(accountIdOf(t)), nil, { reason = reason })
    log('kick', { src = t, actor = actorOf(src), reason = reason })
    DropPlayer(t, 'Você foi removido da cidade: ' .. reason)
end)

command('warn', function(src, args)
    if not allowed(src, 'warnings.write') then return end
    local t = target(src, args[1]); if not t then return end
    local points = A.parsePoints(args[2]); if not points then return fail(src, 'invalid_points') end
    local reason, err = A.reason(args, 3); if not reason then return fail(src, err) end
    local account = accountIdOf(t)
    DB.insert('INSERT INTO warnings (account_id, reason, points, staff_account_id, expires_at) VALUES (?, ?, ?, ?, NOW() + INTERVAL ? DAY)',
        { account, reason, points, accountIdOf(src), A.WarnDays })
    local total = DB.scalar('SELECT COALESCE(SUM(points), 0) FROM warnings WHERE account_id = ? AND expires_at > NOW()', { account })
    audit(src, 'warn', 'account:' .. tostring(account), nil, { points = points, reason = reason, total = total })
    log('warn', { src = t, actor = actorOf(src), points = points, total = total })
    notify(t, ('Você recebeu uma advertência (%d ponto(s)): %s'):format(points, reason), 'warning')
    notify(src, ('Advertência aplicada. Pontos ativos do jogador: %s (5 = ban de 7 dias).'):format(total), 'success')
end)

command('ban', function(src, args)
    local t = target(src, args[1]); if not t then return end
    local duration, err = A.parseDuration(args[2]); if not duration then return fail(src, err) end
    local ok, why = A.canBan(duration, core:HasPermission(src, 'bans.write'), core:HasPermission(src, 'bans.temp'))
    if not ok then log('permission_denied', { src = src, perm = 'bans' }, 'warn') return fail(src, why) end
    local tp = core:GetPlayer(t)
    if tp and tp.staffRole and not core:Outranks(src, t) then return fail(src, 'outranked') end
    local reason, rerr = A.reason(args, 3); if not reason then return fail(src, rerr) end
    ban(src, t, duration, reason)
end)

command('unban', function(src, args)
    if not allowed(src, 'bans.write') then return end
    local id = A.parseTarget(args[1]); if not id then return fail(src, 'not_found') end
    local reason, err = A.reason(args, 2); if not reason then return fail(src, err) end
    local changed = DB.update('UPDATE bans SET revoked_at = NOW() WHERE id = ? AND revoked_at IS NULL', { id })
    if changed ~= 1 then return fail(src, 'not_found') end
    audit(src, 'unban', 'ban:' .. id, nil, { reason = reason })
    log('unban', { actor = actorOf(src), banId = id, reason = reason })
    notify(src, ('Ban #%d revogado.'):format(id), 'success')
end)

local function teleport(src, coords)
    SetEntityCoords(GetPlayerPed(src), coords.x, coords.y, coords.z, false, false, false, false)
end

command('tp', function(src, args)
    if src == 0 or not allowed(src, 'players.teleport') or not inStaffMode(src) then return end
    local t = target(src, args[1]); if not t then return end
    teleport(src, GetEntityCoords(GetPlayerPed(t)))
    log('teleport_to', { src = src, target = t })
end)

command('bring', function(src, args)
    if src == 0 or not allowed(src, 'players.teleport') or not inStaffMode(src) then return end
    local t = target(src, args[1]); if not t then return end
    teleport(t, GetEntityCoords(GetPlayerPed(src)))
    audit(src, 'bring', 'account:' .. tostring(accountIdOf(t)))
    log('bring', { src = t, actor = actorOf(src) })
end)

lib.callback.register('spc_admin:tpm', function(src, coords)
    if not core:HasPermission(src, 'players.teleport') or not staffMode[src] then return false end
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return false end
    teleport(src, coords)
    log('teleport_marker', { src = src })
    return true
end)

command('tpm', function(src)
    if src == 0 or not allowed(src, 'players.teleport') or not inStaffMode(src) then return end
    TriggerClientEvent('spc_admin:client:tpm', src)
end)

command('noclip', function(src)
    if src == 0 or not allowed(src, 'players.teleport') or not inStaffMode(src) then return end
    TriggerClientEvent('spc_admin:client:setNoclip', src, nil) -- nil = alternar
    log('noclip', { src = src })
end)

command('spec', function(src, args)
    if src == 0 or not allowed(src, 'players.spectate') or not inStaffMode(src) then return end
    if args[1] == nil then return TriggerClientEvent('spc_admin:client:spectate', src, nil) end
    local t = target(src, args[1]); if not t or t == src then return end
    log('spectate', { src = src, target = t })
    TriggerClientEvent('spc_admin:client:spectate', src, { id = t, coords = GetEntityCoords(GetPlayerPed(t)) })
end)

command('reviver', function(src, args)
    if not allowed(src, 'players.revive') then return end
    local t = target(src, args[1]); if not t then return end
    audit(src, 'revive', 'account:' .. tostring(accountIdOf(t)))
    log('revive', { src = t, actor = actorOf(src) })
    -- O sistema de hospital tratará este evento; até ele existir, o cliente ressuscita o ped.
    TriggerEvent('spc_admin:server:revive', t, src)
    TriggerClientEvent('spc_admin:client:revive', t)
end)

command('coords', function(src)
    if src == 0 or not allowed(src, 'players.read') then return end
    local c, h = GetEntityCoords(GetPlayerPed(src)), GetEntityHeading(GetPlayerPed(src))
    notify(src, ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, h), 'inform')
end)

AddEventHandler('playerDropped', function() staffMode[source] = nil end)
