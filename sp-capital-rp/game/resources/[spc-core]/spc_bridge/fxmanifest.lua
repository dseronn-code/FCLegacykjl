-- spc_bridge — ponte Redis entre o servidor de jogo, a API, o bot e os workers
-- Spec: docs/sp-capital-rp/specs/logs-e-bridge.md §2
-- Instalação: `npm ci --omit=dev` dentro desta pasta (gera node_modules usado pelo FXServer).
fx_version 'cerulean'
game 'gta5'
name 'spc_bridge'
version '0.1.0'
server_scripts { 'server.js' }
