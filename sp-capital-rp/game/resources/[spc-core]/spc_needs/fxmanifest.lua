-- spc_needs — fome, sede e estresse autoritativos no servidor. Spec: docs/sp-capital-rp/specs/necessidades.md
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'spc_needs'
version '0.1.0'
dependencies { 'spc_core' }
server_scripts { 'shared/needs_core.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
