# ADR-0009: Monorepo com pnpm + Turborepo

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
Tipos, constantes e migrações são compartilhados.

## Decisão
Um monorepo: código em `sp-capital-rp/`, documentação em `docs/sp-capital-rp/` (o app antigo que dividia o repositório foi removido em 2026-11-10).

## Consequências
+ Mudanças atômicas entre jogo, banco e web.
- CI precisa filtrar por caminho.

## Alternativas consideradas
Multi-repo.
