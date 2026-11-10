# Spec: `spc_logs` e `spc_bridge`

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Revisores:** CTO, DevOps
**Fase:** F1 · **Prioridade:** P0

## 1. `spc_logs` (Lua)

### Objetivo
Registrar eventos de gameplay sem nunca bloquear o tick e sem escrever no MariaDB.

### API
`exports.spc_logs:Log(category, action, data, level?)`
- `category`: `connection`, `character`, `money`, `item`, `admin`, `combat`, `police`, ...
- `level`: `debug` | `info` (padrão) | `warn` | `alert`.
- Envelope gerado: `{ts (ms), cat, action, level, resource, src?, citizenid?, license?, data}`.
  Se `data.src` existir, o `spc_logs` preenche `citizenid`/`license` pelo `spc_core`.

### Comportamento
- Buffer em memória; *flush* a cada **2 s** ou ao atingir **500** entradas. Cada lote vira **uma** entrada do stream (`batch` = JSON com `entries` e `dropped`).
- *Flush* = evento servidor local `spc_bridge:logs(batchJson)`.
- Se a ponte não estiver pronta (`GetResourceState('spc_bridge') ~= 'started'`), o buffer cresce até
  **20.000** entradas; acima disso descarta primeiro `debug`, depois os mais antigos, e conta os descartes
  (métrica `logs_dropped`).
- `alert` também é impresso no console do servidor.
- Com `spc_dev 1` e sem ponte, imprime as entradas no console.

## 2. `spc_bridge` (JavaScript, Node do FXServer)

### Objetivo
Única ponte entre o servidor de jogo e o Redis (API, bot, workers).

### Configuração (convars)
| Convar | Exemplo |
|--------|---------|
| `spc_redis_url` | `redis://10.0.0.5:6379` |
| `spc_bridge_secret` | segredo compartilhado com a API (HMAC) — definido via `set` em arquivo fora do repositório |

### Canais
| Canal | Direção | Uso |
|-------|---------|-----|
| `spc:logs` (Stream) | jogo → workers | `XADD` com `MAXLEN ~ 1000000` |
| `spc:cmd` (pub/sub) | API/bot → jogo | comandos |
| `spc:ack:<id>` (pub/sub) | jogo → API/bot | resposta do comando |
| `spc:evt` (pub/sub) | jogo → API/bot | eventos (`player.joined`, `player.dropped`, ...) |

### Formato do comando
Envelope publicado em `spc:cmd`:
```json
{ "body": "{\"id\":\"01J...\",\"type\":\"player.kick\",\"actor\":\"staff:12\",\"ts\":1731240000000,\"payload\":{\"license\":\"license:abc\",\"reason\":\"...\"}}",
  "sig": "<hex hmac-sha256(segredo, body)>" }
```
- `sig` = HMAC-SHA256(segredo, `body`) calculado sobre a **string exata** de `body` (sem reserializar,
  evitando divergência de ordem de chaves). Comparação em tempo constante.
- Recusado se: assinatura inválida, `ts` com mais de 30 s de diferença, `id` repetido (cache de 10 min),
  `type` fora do padrão `^[a-z]+\.[a-z_]+$`.
- Comando aceito → evento **servidor local** `spc:cmd:<type>(id, payload, actor)`. Os recursos Lua devem usar
  `AddEventHandler` (nunca `RegisterNetEvent`) para esses eventos, garantindo que clientes não possam disparar.
- O recurso que trata responde com `exports.spc_bridge:Ack(id, ok, result)`. Sem resposta em 10 s, a ponte
  publica `{ok:false, error:"timeout"}`.

### Exports
`Ack(id, ok, result)`, `Publish(type, payload)`, `IsConnected()`.

### Resiliência
- Reconexão automática com *backoff* exponencial (máx. 30 s). Enquanto desconectada, `spc_bridge:logs`
  mantém até 50 lotes em memória e descarta os mais antigos.
- A queda do Redis **não** afeta o gameplay (apenas logs, painel e bot ficam atrasados).

## 3. Critérios de aceite
1. Log nunca bloqueia: chamada a `Log` só insere em tabela Lua.
2. Comando sem assinatura ou com assinatura inválida é descartado e logado como `alert`.
3. `player.kick` vindo do painel derruba o jogador e gera `ack` com sucesso.
