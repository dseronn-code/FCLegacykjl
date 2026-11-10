# ADR-0003: Lua 5.4 nos recursos de jogo

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
O runtime Lua do FiveM é o mais performático e tem o maior ecossistema.

## Decisão
Todo recurso de jogo em Lua 5.4 (`lua54 'yes'`). JavaScript apenas quando for preciso usar bibliotecas Node (ex.: `spc_bridge` com Redis).

## Consequências
+ Performance e contratação.
- Duas linguagens no monorepo (Lua e TS).

## Alternativas consideradas
C#, JS em todos os recursos.
