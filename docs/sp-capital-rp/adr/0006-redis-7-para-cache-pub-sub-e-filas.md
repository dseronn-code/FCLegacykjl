# ADR-0006: Redis 7 para cache, pub/sub e filas

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
O jogo, a API e o bot precisam trocar comandos e eventos em tempo real sem HTTP no caminho crítico.

## Decisão
Redis 7: canais `spc:cmd`/`spc:evt`, respostas em `spc:ack:<id>`, stream `spc:logs`. Acesso do jogo apenas via `spc_bridge`.

## Consequências
+ Baixa latência, simples.
- Mais um componente para operar; precisa de persistência AOF para o stream de logs.

## Alternativas consideradas
RabbitMQ, HTTP direto.
