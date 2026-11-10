# ADR-0009: Monorepo com pnpm + Turborepo

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
Tipos, constantes e migrações são compartilhados.

## Decisão
Um monorepo; neste repositório ele vive em `sp-capital-rp/` (o restante do repositório contém outro projeto).

## Consequências
+ Mudanças atômicas entre jogo, banco e web.
- CI precisa filtrar por caminho.

## Alternativas consideradas
Multi-repo.
