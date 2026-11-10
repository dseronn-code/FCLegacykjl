# ADR-0008: Next.js 15 + Fastify para painel e API

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
O painel precisa de SSR e a API deve ser independente do front.

## Decisão
`apps/panel` (Next.js) consome `services/api` (Fastify, OpenAPI).

## Consequências
+ API reutilizável pelo bot e por workers.
- Dois deploys.

## Alternativas consideradas
Monólito Express.
