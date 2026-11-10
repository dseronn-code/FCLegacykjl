# ADR-0002: Core próprio sobre o stack Overextended

**Status:** ACEITO · **Data:** 2026-11-10 · **Decisor:** CTO

## Contexto
Frameworks prontos (ESX, QBCore) acoplam economia e permissões de forma que não controlamos e têm histórico de problemas de performance.

## Decisão
Criar `spc_core` (contas, personagens, permissões, ledger) usando `ox_lib`, `oxmysql`, `ox_inventory` e `ox_target` como dependências com versão fixada.

## Consequências
+ Controle total do dinheiro e da autoridade do servidor.
- Recursos de terceiros feitos para ESX/QB precisam de adaptador ou reescrita.

## Alternativas consideradas
ESX, QBCore, QBox puro.
