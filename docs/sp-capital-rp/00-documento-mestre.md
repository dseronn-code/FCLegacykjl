# 00 — Documento Mestre (Game Design Document)

**Status:** EM REVISÃO · **Versão:** 0.1 · **Dono:** CTO / Lead Developer

---

## 1. Visão

> **Ser a cidade de roleplay mais viva, justa e estável do mundo — uma São Paulo onde cada
> jogador tem uma história, cada real tem origem e cada ação tem consequência.**

SP Capital RP é um servidor FiveM (GTA V) de roleplay sério (*serious RP*) com economia
controlada, instituições funcionais (polícia, hospital, DETRAN, justiça, prefeitura) e
um ecossistema criminal com risco real. A cidade é inspirada na cultura, gírias, trânsito,
bairros e rotina de São Paulo, adaptada ao mapa de Los Santos com MLOs e nomes fictícios.

## 2. Pilares de design

| Pilar | O que significa | Como medimos |
|-------|-----------------|--------------|
| **1. Estabilidade primeiro** | 500+ jogadores sem lag, sem crash, sem rollback | Uptime ≥ 99,5%, tick server < 30%, crashes/dia |
| **2. Economia com significado** | Dinheiro é difícil de ganhar e tem para onde ir | Razão dreno/fonte 0,85–1,0; índice de preços estável |
| **3. Consequência** | Crime gera risco; morte gera custo; dívida gera cobrança | % de crimes com resposta policial, taxa de reincidência |
| **4. Instituições vivas** | Polícia, hospital, DETRAN e justiça funcionam por jogadores | Cobertura de serviço por horário (meta: 90% das horas) |
| **5. Identidade paulistana** | Gírias, lugares, culinária, trânsito, futebol, cultura | Pesquisa de satisfação, retenção D30 |
| **6. Justiça e transparência** | Staff auditável, regras claras, punições consistentes | Tempo de resposta de ticket, % de punições revertidas |

## 3. Público-alvo

- **Primário:** jogadores brasileiros 16+ (PT-BR), experiência prévia em RP, PC médio/alto.
- **Secundário:** criadores de conteúdo (streamers Twitch/Kick/YouTube) — o servidor deve ser
  *assistível*: eventos, histórias longas, conflitos interessantes.
- **Faixa etária:** 16+ (conteúdo com violência, crime e linguagem adulta). Verificação no whitelist.

## 4. Modelo de acesso

- **Whitelist** obrigatória (formulário + entrevista por voz) — ver [11-discord.md](11-discord.md).
- **Fila prioritária** limitada e transparente (ver regra de monetização abaixo).
- **Slots:** 512 no lançamento (OneSync Infinity), meta de 700 após otimização comprovada.

## 5. Regras de ouro (inegociáveis)

1. **O servidor é autoritativo.** O cliente nunca decide dinheiro, itens, dano final ou permissões.
2. **Todo dinheiro tem origem.** Toda movimentação passa pelo *ledger* (livro-razão) com motivo.
3. **Documentar antes de programar.** Sem spec aprovada, sem merge.
4. **Sem pay-to-win.** Monetização apenas via Tebex, respeitando os termos da Cfx.re (FiveM);
   apenas cosméticos, fila prioritária com limite e apoio. Nunca dinheiro, armas ou vantagem de jogo.
   *(Revisar o PLA/termos da Cfx.re vigentes antes de abrir a loja.)*
5. **Nada de entidades reais.** Facções, empresas e marcas são fictícias.
6. **Staff não joga com poder.** Contas de staff separadas das ações de personagem; toda ação admin é logada.
7. **Performance é feature.** Todo recurso tem orçamento de CPU e passa por perfilamento antes do deploy.

## 6. Regras de RP (resumo — documento completo de regras é público no site/Discord)

- Proibidos: RDM (matar sem motivo), VDM (atropelar intencionalmente), metagaming, powergaming,
  combat logging, anti-RP, uso de bugs, "dark RP" sexual ou discriminatório.
- **Amor à vida:** o personagem deve temer pela própria vida.
- **Ações criminosas** exigem número mínimo de policiais em serviço (ver [06-faccoes.md](06-faccoes.md)).
- **Morte de personagem (CK)** só com consentimento ou por decisão de staff em casos extremos.
- **Tempo de cooldown** após ações grandes (assaltos a banco, guerras).

## 7. Mapa e ambientação

O mapa é Los Santos, rebatizado e reambientado como **"SP Capital"**:

| Área real GTA | Nome em SP Capital | Vibe |
|---------------|-------------------|------|
| Downtown / Pillbox | **Centro / Sé Velha** | Prefeitura, fórum, hospital central |
| Rockford Hills | **Jardins do Norte** | Ricos, lojas de luxo, mansões |
| Vinewood Blvd | **Avenida Paulistana** | Ponto turístico, eventos, protestos |
| Del Perro / Vespucci | **Litoral Sul** | Praia, comércio, turismo |
| Grove / Davis / Rancho | **Zona Leste Fictícia** (Vila Aurora, Jardim Esperança) | Comunidades, bailes, facções |
| Sandy Shores | **Interior / Serra Verde** | Rural, desmanche, laboratórios |
| Paleto Bay | **Vila do Porto** | Pesca, madeireira |
| LSIA | **Aeroporto Internacional da Capital** | Logística, contrabando |
| Porto de LS | **Porto da Capital** | Caminhoneiros, contêineres |

- Veículos: pack de carros brasileiros com **nomes fictícios** (ex.: "Volta Gol" → "Gaúcho G1").
- Comida/lojas: padaria, pastelaria, açaí, churrascaria, mercadinho, posto 24h.
- Clima e horário sincronizados; ciclo de dia de 2h reais (configurável).

## 8. Estrutura do time

| Papel | Responsabilidade |
|-------|------------------|
| **CTO / Lead Dev** | Arquitetura, revisão de código, performance, segurança, aprovação de specs |
| **Devs Game (Lua)** | Recursos do servidor/cliente FiveM |
| **Devs Web (TS)** | API, painel web, bot Discord |
| **DBA / DevOps** | Infra, banco, backups, CI/CD, monitoramento, DDoS |
| **Designer de Economia** | Preços, balanceamento, dashboards de economia |
| **Mappers / 3D** | MLOs, veículos, roupas, otimização de assets (streaming) |
| **UI/UX** | NUI (HUD, celular, tablets), painel web |
| **QA** | Testes, playtests, regressão |
| **Head de Staff** | Moderação, regras, tickets, whitelist |
| **Líderes de Instituição** | Polícia, hospital, DETRAN, justiça (jogadores com cargo de coordenação) |

## 9. Roadmap

| Fase | Duração estimada | Entregas | Critério de saída |
|------|------------------|----------|-------------------|
| **F0 — Documentação** | 3–4 semanas | Todos os docs desta pasta aprovados; ADRs iniciais | 100% dos docs `APROVADO` |
| **F1 — Fundação** | 6–8 semanas | Infra, CI/CD, `spc_core` (contas, personagens, ledger, permissões), inventário, HUD, voz, logs, painel staff mínimo, bot Discord (whitelist) | Testes automatizados verdes; 64 jogadores internos estáveis |
| **F2 — Cidade básica** | 6–8 semanas | Empregos iniciais, banco, veículos/garagens, DETRAN, hospital, polícia (MDT básico), celular, casas | Alpha fechado 100 jogadores, 0 crash em 4h |
| **F3 — Ecossistema** | 8 semanas | Facções, territórios, crimes, empresas, justiça, painel jogador | Beta 250 jogadores, tick < 30% |
| **F4 — Lançamento** | 4 semanas | Otimização, teste de carga, eventos de lançamento, loja Tebex cosmética | **500 jogadores** com tick < 35% e p95 de latência DB < 15 ms |
| **F5 — Live Ops** | Contínuo | Temporadas, eventos, novos empregos, balanceamento mensal | KPIs da seção 10 |

## 10. KPIs

| Área | KPI | Meta |
|------|-----|------|
| Técnico | Uptime mensal | ≥ 99,5% |
| Técnico | Tempo de *server thread* (pico) | < 35% |
| Técnico | Tempo de entrada (conectar → spawn) | < 60 s (cache de assets) |
| Técnico | Crashes de cliente atribuíveis ao servidor | < 1% das sessões |
| Comunidade | Pico de jogadores simultâneos | 500+ |
| Comunidade | Retenção D7 / D30 | 45% / 25% |
| Comunidade | Fila de whitelist | < 72 h |
| Economia | Razão dreno/fonte semanal | 0,85–1,0 |
| Economia | Variação do índice de preços (cesta) | ± 5%/mês |
| Staff | Tempo de primeira resposta em ticket | < 15 min (horário de pico) |

## 11. Riscos principais

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Lag/crash com 500+ | Crítico | Orçamento de CPU por recurso, teste de carga por fase, OneSync com *entity lockdown*, perfilamento obrigatório |
| Cheaters (money/item spawn) | Crítico | Servidor autoritativo, ledger, rate limit em eventos, anticheat, alertas de anomalia |
| Inflação | Alto | Drenos dimensionados, dashboards, revisões mensais (ver [05-economia.md](05-economia.md)) |
| DDoS | Alto | Host com mitigação, proxy de conexão, IP do servidor oculto atrás de proxies Cfx |
| Vazamento de scripts | Médio | Repositório privado, escrow onde aplicável, segredos em cofre, lógica sensível só no servidor |
| Burnout de staff | Médio | Escalas, ferramentas boas, automação de tickets |
| Termos da Cfx.re / Rockstar | Alto | Sem monetização proibida, sem conteúdo proibido, revisão jurídica da loja |
| LGPD | Médio | Dados mínimos, política de privacidade, exclusão sob pedido (ver [02-banco-de-dados.md](02-banco-de-dados.md)) |

## 12. Glossário

- **OneSync Infinity:** modo de sincronização do FiveM que permite até 2048 slots com *culling* por distância.
- **Ledger:** livro-razão de dupla entrada para movimentações financeiras.
- **Routing bucket:** "dimensão" isolada no FiveM (instâncias de casas, testes do DETRAN etc.).
- **State bag:** mecanismo nativo do FiveM para replicar estado de entidades/jogadores.
- **NUI:** interface HTML/JS dentro do jogo (HUD, celular, tablets).
- **MDT:** *Mobile Data Terminal*, tablet policial.
- **CK:** *Character Kill*, morte permanente do personagem.
