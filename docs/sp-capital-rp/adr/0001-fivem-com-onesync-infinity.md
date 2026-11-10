# ADR-0001: FiveM com OneSync Infinity

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
Precisamos de 500+ jogadores simultâneos em GTA V com ecossistema de RP maduro.

## Decisão
Usar FiveM (FXServer) com `onesync on` (Infinity), `sv_maxclients 512` no lançamento e `sv_entityLockdown strict`.

## Consequências
+ Plataforma padrão do RP brasileiro; suporta até 2048 slots.
- Server thread majoritariamente single-thread: exige CPU de alto clock e disciplina de performance.
- Sujeito aos termos da Cfx.re (monetização, conteúdo).

## Alternativas consideradas
RageMP (ecossistema menor), alt:V (descontinuado).
