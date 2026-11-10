# ADR-0007: Logs de alto volume fora do MariaDB

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
Com 500 jogadores são ~10 milhões de eventos de log por dia.

## Decisão
Jogo agrega logs em lote → Redis Stream `spc:logs` → worker → ClickHouse (retenção de 180 dias). Apenas `audit_log` de staff fica no MariaDB.

## Consequências
+ O banco transacional não degrada.
- Se o Redis cair, o `spc_logs` mantém buffer limitado em memória e descarta os logs de menor prioridade.

## Alternativas consideradas
Logs no MariaDB, webhooks do Discord.
