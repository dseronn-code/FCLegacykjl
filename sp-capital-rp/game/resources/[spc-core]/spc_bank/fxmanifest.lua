-- spc_bank — Banco Capital: agências, caixas, saque, depósito, PIX. Spec: docs/sp-capital-rp/specs/banco.md
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'spc_bank'
version '0.1.0'
dependencies { 'spc_core', 'ox_inventory', 'ox_lib', 'ox_target' }
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'shared/bank_core.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
