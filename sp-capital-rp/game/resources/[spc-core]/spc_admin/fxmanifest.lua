-- spc_admin — ferramentas de staff no jogo (permissões no servidor, tudo auditado)
-- Spec: docs/sp-capital-rp/specs/spc_admin.md
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'spc_admin'
version '0.1.0'
dependencies { 'spc_core', 'oxmysql', 'ox_lib' }
shared_scripts { '@ox_lib/init.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', '@spc_core/shared/util.lua', 'shared/admin_core.lua', 'server/db.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
