# SP Capital RP — Documentação Técnica e de Design

> **Regra de ouro do projeto:** nada é programado sem estar documentado e aprovado.
> Todo sistema nasce como documento (spec/RFC), passa por revisão e só então vira código.

Esta pasta é a fonte única da verdade (*single source of truth*) do SP Capital RP, uma cidade
GTA RP (FiveM) ambientada numa São Paulo fictícia, projetada para **500+ jogadores simultâneos**.

## Índice

| # | Documento | Conteúdo |
|---|-----------|----------|
| 00 | [Documento Mestre](00-documento-mestre.md) | Visão, pilares, público, regras de ouro, governança, roadmap, KPIs, riscos |
| 01 | [Arquitetura](01-arquitetura.md) | Stack, topologia de servidores, escala para 500+, segurança, monorepo, observabilidade |
| 02 | [Banco de Dados](02-banco-de-dados.md) | Modelo de dados, tabelas, índices, ledger financeiro, retenção, backup |
| 03 | [Sistemas](03-sistemas.md) | Catálogo de todos os sistemas de gameplay e infraestrutura |
| 04 | [Empregos](04-empregos.md) | Empregos legais, progressão, pagamentos, anti-farm |
| 05 | [Economia](05-economia.md) | Moeda, fontes e drenos, preços de referência, impostos, controle de inflação |
| 06 | [Facções](06-faccoes.md) | Organizações legais e ilegais, territórios, guerras, regras |
| 07 | [Empresas](07-empresas.md) | Empresas de jogadores, tipos, licenças, folha, estoque, falência |
| 08 | [Polícia](08-policia.md) | Corporações, hierarquia, MDT, prisão, evidências, Código Q |
| 09 | [Hospital](09-hospital.md) | Sistema de ferimentos, atendimento, morte/respawn, prontuário |
| 10 | [DETRAN](10-detran.md) | CNH, emplacamento, IPVA, multas/pontos, pátio, leilão |
| 11 | [Discord](11-discord.md) | Estrutura do servidor, bot, whitelist, sincronização de cargos, logs |
| 12 | [Painel Web](12-painel-web.md) | Painel do jogador, staff, facções e empresas; APIs; RBAC |
| 13 | [Processo de Desenvolvimento](13-processo-desenvolvimento.md) | RFC/ADR, padrões, Definition of Done, testes, deploy |

### Decisões, specs e documentos públicos

| Pasta | Conteúdo |
|-------|----------|
| [adr/](adr/README.md) | ADR-0001 a 0010 (FiveM/OneSync, core próprio, Lua, TS, MariaDB, Redis, logs, painel, monorepo, voz) |
| [specs/](specs/) | Specs P0: [spc_core](specs/spc_core.md), [ledger](specs/ledger.md), [logs e ponte](specs/logs-e-bridge.md), [whitelist e fila](specs/fila-whitelist.md), [multichar](specs/spc_multichar.md), [inventário](specs/inventario.md), [HUD](specs/hud.md), [admin](specs/spc_admin.md), [API e bot](specs/api-e-bot-whitelist.md) |
| [publico/](publico/) | [Código Penal](publico/codigo-penal.md) e [Regulamento Geral](publico/regulamento-geral.md) |

Código: [`/sp-capital-rp`](../../sp-capital-rp/README.md).

## Status dos documentos

| Status | Significado |
|--------|-------------|
| `RASCUNHO` | Em escrita, pode mudar livremente |
| `EM REVISÃO` | Aberto para comentários do time (prazo: 5 dias úteis) |
| `APROVADO` | Pode ser implementado; mudanças exigem RFC |
| `IMPLEMENTADO` | Código em produção reflete o documento |

Documentos 00–13: **`APROVADO` — v1.0 (2026-11-10)**. Novos documentos (ADRs, specs, documentos públicos) têm status próprio no cabeçalho.

## Convenções

- Idioma: português (BR). Nomes de código, tabelas e eventos: inglês, `snake_case`.
- Prefixo de recursos do servidor: `spc_` (ex.: `spc_core`, `spc_police`).
- Valores monetários: inteiros em **centavos** (`BIGINT`) no banco; exibidos como `R$ 1.234,56`.
- Todos os nomes de marcas, organizações e locais reais são substituídos por versões **fictícias**
  (evita problemas de marca registrada e de apologia a organizações criminosas reais).
