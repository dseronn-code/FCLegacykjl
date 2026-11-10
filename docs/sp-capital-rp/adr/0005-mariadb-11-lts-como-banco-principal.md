# ADR-0005: MariaDB 11 LTS como banco principal

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
O `oxmysql` é o driver mais maduro e é compatível com MySQL/MariaDB.

## Decisão
MariaDB 11 LTS, InnoDB, `utf8mb4`, UTC, migrações SQL versionadas em `packages/db/migrations`.

## Consequências
+ Desempenho e replicação simples.
- Chaves únicas em tabelas particionadas precisam incluir a coluna de partição (resolvido com a tabela `ledger_tx` de idempotência).

## Alternativas consideradas
PostgreSQL.
