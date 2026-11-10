-- spc_core — contas, conexão, personagens, permissões e ledger
-- Spec: docs/sp-capital-rp/specs/spc_core.md · docs/sp-capital-rp/specs/ledger.md
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'spc_core'
author 'SP Capital RP'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib' }

shared_scripts { '@ox_lib/init.lua' }

-- Toda a lógica e configuração ficam só no servidor (o cliente não recebe regras nem valores).
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'shared/util.lua',
    'shared/identity.lua',
    'shared/permissions_core.lua',
    'shared/ledger_core.lua',
    'server/db.lua',
    'server/log.lua',
    'server/players.lua',
    'server/permissions.lua',
    'server/ledger.lua',
    'server/connection.lua',
    'server/characters.lua',
    'server/persistence.lua',
    'server/commands.lua',
    'server/exports.lua',
    'server/dev.lua',
}

client_scripts { 'client/main.lua' }
