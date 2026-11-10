# SP Capital RP — Código

Monorepo da cidade (ADR-0009). Documentação, specs e decisões ficam em [`../docs/sp-capital-rp`](../docs/sp-capital-rp).
**Nenhum código entra sem spec aprovada** ([processo](../docs/sp-capital-rp/13-processo-desenvolvimento.md)).

## Estado atual — Fase 1 (Fundação)

| Componente | Spec | Estado |
|------------|------|--------|
| `spc_core` — conexão, whitelist, ban (inclui tokens de hardware), personagens, permissões, persistência | [spc_core](../docs/sp-capital-rp/specs/spc_core.md) | ✅ testado fora do FXServer |
| Ledger financeiro (dupla entrada, idempotente, atômico) | [ledger](../docs/sp-capital-rp/specs/ledger.md) | ✅ testado contra MariaDB |
| `spc_logs` + `spc_bridge` (Redis, comandos HMAC, jogadores online) | [logs-e-bridge](../docs/sp-capital-rp/specs/logs-e-bridge.md) | ✅ fumaça com Redis real |
| `spc_admin` — modo staff, kick, warn, ban/unban, tp, noclip, spectate, reviver | [spc_admin](../docs/sp-capital-rp/specs/spc_admin.md) | ✅ testado (integração) |
| `spc_multichar` — tela de personagens (NUI) | [spc_multichar](../docs/sp-capital-rp/specs/spc_multichar.md) | ✅ NUI testada no navegador |
| `spc_hud` — vida, colete, fome, sede, estresse, voz, rádio, rua, velocímetro | [hud](../docs/sp-capital-rp/specs/hud.md) | ✅ NUI testada no navegador |
| Inventário — ponte `spc` do `ox_inventory`, itens, kit inicial | [inventario](../docs/sp-capital-rp/specs/inventario.md) | ✅ código; depende do FXServer |
| API (`services/api`) — whitelist e status | [api-e-bot-whitelist](../docs/sp-capital-rp/specs/api-e-bot-whitelist.md) | ✅ testada contra MariaDB e Redis |
| Bot do Discord (`apps/discord-bot`) — formulário, revisão, cargo, `/status` | [api-e-bot-whitelist](../docs/sp-capital-rp/specs/api-e-bot-whitelist.md) | ✅ tipos e lógica testados; falta rodar num Discord real |
| Migrações 0001–0003 | [02-banco-de-dados](../docs/sp-capital-rp/02-banco-de-dados.md) | ✅ |

## Estrutura

```
game/
  server.cfg.example
  resources/[spc-core]/  spc_core · spc_logs · spc_bridge · spc_admin · spc_multichar · spc_hud
  overlays/ox_inventory/ ponte "spc" + itens (instalados por infra/scripts/install-overlays.sh)
services/api/            Fastify + TypeScript
apps/discord-bot/        discord.js v14
packages/
  db/migrations/         SQL versionado · db/queries/ (reconciliação, mint/sink)
  shared/                penal-code.json e permissions.json (gerados — não editar à mão)
infra/                   docker-compose.dev.yml · mariadb/spc.cnf · scripts/
tests/
  lua/                   testes unitários (Lua 5.4)
  integration/           Lua real do servidor (wasmoon) + FiveM/oxmysql simulados + MariaDB real
```

## Rodando localmente

```bash
docker compose -f infra/docker-compose.dev.yml up -d
MYSQL="mariadb -h127.0.0.1 -uroot -pdev" DB_NAME=spcapital infra/scripts/migrate.sh

# testes
lua5.4 tests/lua/run.lua
node 'game/resources/[spc-core]/spc_bridge/protocol.test.js'
(cd tests/integration && npm ci && DB_HOST=127.0.0.1 DB_USER=root DB_PASSWORD=dev npm test)
(cd services/api && npm ci && DB_HOST=127.0.0.1 DB_USER=root DB_PASSWORD=dev REDIS_URL=redis://127.0.0.1:6379 npm test)
(cd apps/discord-bot && npm ci && npm test)

# arquivos gerados (rodar após mudar o Código Penal ou as permissões)
python3 infra/scripts/gen-penal-code.py
lua5.4 infra/scripts/gen-permissions.lua
```

### Servidor FiveM (staging)
1. Baixe `oxmysql`, `ox_lib`, `ox_inventory` e `pma-voice` (versões fixadas no primeiro boot e registradas aqui).
2. `infra/scripts/install-overlays.sh <caminho>/ox_inventory`.
3. Copie `game/resources/[spc-core]` para `resources/` e rode `npm ci --omit=dev` em `spc_bridge/`.
4. Crie `server.cfg` a partir do exemplo e um `secrets.cfg` fora do git.
5. Libere sua conta: `INSERT INTO accounts (discord_id, whitelist_status) VALUES ('<seu id>', 'approved');`
   e `INSERT INTO staff (account_id, role) SELECT id, 'owner' FROM accounts WHERE discord_id = '<seu id>';`

### API e bot
Copie `.env.example` → `.env` em `services/api` e `apps/discord-bot` e preencha. `SPC_API_TOKEN` deve ser o mesmo nos dois;
`SPC_BRIDGE_SECRET` da API deve ser igual à convar `spc_bridge_secret` do jogo. `npm start` em cada pasta.
O bot precisa da permissão **Gerenciar cargos**, com o cargo dele acima do cargo `Cidadão`.

## Limitações conhecidas

- **Nada foi executado ainda dentro de um FXServer nem num Discord real.** O primeiro boot em staging é o próximo critério de aceite.
- Comida e bebida ainda não alteram fome e sede (spec de necessidades pendente). O HUD mostra o status que o servidor enviar.
- Itens e grupos de emprego chegam com as specs de empregos; licenças (CNH, porte), com a do DETRAN.
