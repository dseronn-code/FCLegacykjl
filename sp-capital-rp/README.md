# SP Capital RP — Código

Monorepo da cidade (ADR-0009). Documentação, specs e decisões ficam em [`../docs/sp-capital-rp`](../docs/sp-capital-rp).
**Nenhum código entra sem spec aprovada** ([processo](../docs/sp-capital-rp/13-processo-desenvolvimento.md)).

## Estado atual — Fase 1 (Fundação), incremento 1

| Componente | Spec | Estado |
|------------|------|--------|
| `spc_core` — conexão, whitelist, ban, personagens, permissões, persistência | [spc_core.md](../docs/sp-capital-rp/specs/spc_core.md) | Implementado, testado fora do FXServer |
| Ledger financeiro (dupla entrada, idempotente, atômico) | [ledger.md](../docs/sp-capital-rp/specs/ledger.md) | Implementado e testado contra MariaDB |
| `spc_logs` | [logs-e-bridge.md](../docs/sp-capital-rp/specs/logs-e-bridge.md) | Implementado |
| `spc_bridge` (Redis, comandos HMAC) | [logs-e-bridge.md](../docs/sp-capital-rp/specs/logs-e-bridge.md) | Implementado, teste de fumaça com Redis real |
| Migrações 0001–0002 | [02-banco-de-dados.md](../docs/sp-capital-rp/02-banco-de-dados.md) | Implementadas |
| Código Penal em JSON | [codigo-penal.md](../docs/sp-capital-rp/publico/codigo-penal.md) | Gerado por script |

Próximo incremento (specs a escrever antes): `spc_multichar` (NUI de personagens), inventário (`ox_inventory`
configurado com `money`/`dirty_money`), HUD, `spc_admin`, bot de whitelist, API mínima.

## Estrutura

```
game/
  server.cfg.example
  resources/[spc-core]/
    spc_core/      Lua — shared/ (lógica pura, testável) · server/ · client/
    spc_logs/      Lua — buffer de logs em lote
    spc_bridge/    JS  — Redis (logs, comandos assinados, eventos)
packages/
  db/migrations/   SQL versionado · db/queries/ (reconciliação, mint/sink)
  shared/          penal-code.json (gerado)
infra/
  docker-compose.dev.yml · mariadb/spc.cnf · scripts/migrate.sh · scripts/gen-penal-code.py
tests/
  lua/             testes unitários (Lua 5.4 puro)
  integration/     Lua real do servidor (wasmoon) + oxmysql simulado + MariaDB real
```

## Rodando localmente

```bash
docker compose -f infra/docker-compose.dev.yml up -d
MYSQL="mariadb -h127.0.0.1 -uroot -pdev" DB_NAME=spcapital infra/scripts/migrate.sh

# testes
lua5.4 tests/lua/run.lua
node 'game/resources/[spc-core]/spc_bridge/protocol.test.js'
(cd tests/integration && npm ci && DB_HOST=127.0.0.1 DB_USER=root DB_PASSWORD=dev npm test)
```

Servidor FiveM: copie `game/resources/*` para a pasta `resources` do FXServer junto com `oxmysql` e `ox_lib`
(versões fixadas), rode `npm ci --omit=dev` em `spc_bridge/`, crie `server.cfg` a partir do exemplo e um
`secrets.cfg` fora do git. Para testar sem a tela de personagens, use `setr spc_dev 1` e os comandos
`/spc_criar Nome Sobrenome AAAA-MM-DD m`, `/spc_personagens`, `/spc_entrar SPCXXXXX`, `/spc_saldo`.

Para liberar sua conta localmente:
```sql
INSERT INTO accounts (discord_id, whitelist_status) VALUES ('<seu id do Discord>', 'approved');
INSERT INTO staff (account_id, role) SELECT id, 'owner' FROM accounts WHERE discord_id = '<seu id>';
```

## Limitações conhecidas deste incremento

- **Ainda não foi executado dentro de um FXServer.** O Lua do servidor roda nos testes de integração com
  FiveM/oxmysql simulados; o primeiro boot real em `staging` é o próximo critério de aceite.
- `account.refresh` e `player.kick` existem, mas ainda não há API/bot que os publique.
- Sem fila com prioridade (Fase 3, ver [fila-whitelist.md](../docs/sp-capital-rp/specs/fila-whitelist.md)).
