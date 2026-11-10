# ADR-0004: TypeScript (Node 22 LTS) para API, bot e painel

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
Serviços web precisam compartilhar tipos e constantes.

## Decisão
API (Fastify), bot (discord.js) e painel (Next.js) em TypeScript estrito, pacote `packages/shared` com tipos.

## Consequências
+ Um time web, tipagem fim a fim.
- Constantes de jogo precisam ser exportadas também para Lua (gerar JSON).

## Alternativas consideradas
Python, Go.
