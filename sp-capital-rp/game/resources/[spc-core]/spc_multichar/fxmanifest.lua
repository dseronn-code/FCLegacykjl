-- spc_multichar — seleção e criação de personagem (NUI). Regras ficam no spc_core.
-- Spec: docs/sp-capital-rp/specs/spc_multichar.md
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'spc_multichar'
version '0.1.0'
dependencies { 'spc_core', 'ox_lib' }
shared_scripts { '@ox_lib/init.lua' }
client_scripts { 'client.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
