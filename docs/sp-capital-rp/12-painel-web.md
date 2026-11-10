# 12 — Painel Web

**Status:** EM REVISÃO · **Versão:** 0.1 · **Dono:** Dev Web

---

## 1. Visão geral

Um único aplicativo web (`apps/panel`, Next.js) com quatro áreas, servido por uma API (`services/api`,
Fastify), autenticado via **Discord OAuth2**.

| Área | Usuários | URL |
|------|----------|-----|
| **Site público** | Todos | `spcapital.gg` (exemplo) |
| **Painel do Cidadão** | Jogadores aprovados | `/cidadao` |
| **Painel Institucional / Facção / Empresa** | Membros com cargo | `/org/<id>` |
| **Painel Staff** | Staff (2FA obrigatório) | `/staff` |

## 2. Site público

- Apresentação da cidade, regras completas, código penal, FAQ, mapa ilustrado dos bairros.
- Status do servidor em tempo real (jogadores, fila).
- Changelog e roadmap público.
- Loja (link para Tebex, apenas cosméticos/apoio).
- Política de privacidade (LGPD) e termos.

## 3. Painel do Cidadão

| Módulo | Conteúdo |
|--------|----------|
| Personagens | Lista, dados básicos, horas jogadas |
| Banco | Saldo, extrato (com filtro), PIX agendado (P2) |
| Veículos | Lista, situação, IPVA, multas, histórico, localização (garagem/pátio) |
| DETRAN | Multas e pagamento, CNH, pontos, leilão |
| Imóveis | Propriedades, aluguel, IPTU |
| Emprego | Nível, XP, ganhos da semana |
| Punições | Advertências, bans e revisão |
| Tickets | Histórico |

> **Regra:** pagamentos pelo painel usam o mesmo serviço de ledger. Se o personagem está online, a
> operação é enviada ao jogo via Redis; se offline, a API executa a transação.

## 4. Painel Institucional / Facção / Empresa

- Membros, cargos, contratação/demissão (com permissão).
- Ponto eletrônico e horas por membro; escalas.
- Folha de pagamento (empresas), faturamento, estoque.
- Logs de baú e de conta (quem movimentou o quê).
- Polícia: estatísticas da corporação, Corregedoria (denúncias).
- Facções: influência territorial, guerras (declarar/acompanhar).

## 5. Painel Staff

| Módulo | Função | Papel mínimo |
|--------|--------|--------------|
| Jogadores | Busca por license/discord/citizenid/nome; perfil completo; histórico | Helper |
| Ao vivo | Lista online, mapa ao vivo (posições a cada 10 s via réplica/Redis), kick, spectate remoto (abre no jogo) | Moderador |
| Punições | Advertir, banir (temporário/permanente), revisar | Moderador (ban perm: Admin) |
| Logs | Busca no ClickHouse: dinheiro, itens, mortes, chat, conexões — com filtros e exportação | Moderador |
| Economia | Dashboards: M2, mint/sink, top fortunas, anomalias; **reversão por `tx_id`** | Admin + Head de Economia |
| Whitelist | Fila de formulários, agendamento de entrevistas, aprovação | Helper |
| Tickets | Transcrições, métricas de atendimento | Helper |
| Facções/Empresas | Aprovação, suspensão, revisão trimestral | Head |
| Itens/Preços | Editar tabelas de preço (gera RFC/aprovação dupla) | Head + Dev |
| Servidor | Anúncios, restart agendado, status de recursos | Dev / Diretoria |
| Auditoria | Toda ação de staff, com antes/depois | Diretoria |

## 6. Segurança e RBAC

- Login **Discord OAuth2**; sessão em cookie `HttpOnly`, `Secure`, `SameSite=Lax`; expiração de 12 h (staff: 4 h).
- **2FA TOTP obrigatório** para qualquer papel de staff.
- RBAC por **permissões granulares** (`players.read`, `bans.write`, `economy.revert`...) atribuídas a papéis.
- Ações destrutivas (ban permanente, reversão econômica > R$ 1 mi, edição de preços) exigem **aprovação de 2 pessoas**.
- Rate limit por IP e por usuário; proteção CSRF; validação de entrada com schema (Zod).
- **Toda escrita** gera registro em `audit_log`.
- Painel lê da **réplica**; escreve só via serviços da API (nunca SQL arbitrário).

## 7. API

- REST versionada (`/v1`), documentação OpenAPI gerada automaticamente.
- Endpoints internos (bot, workers) autenticados por token de serviço + rede privada.
- Nenhum endpoint público expõe dados de outro jogador sem permissão (ex.: posição de jogadores nunca é pública).
- Exemplos:
  - `GET /v1/me/characters`
  - `GET /v1/characters/:citizenid/bank/statement?from&to`
  - `POST /v1/fines/:id/pay`
  - `POST /v1/staff/bans` (perm `bans.write`)
  - `POST /v1/staff/economy/revert` (perm `economy.revert`, dupla aprovação)

## 8. Stack e UX

- Next.js 15 (App Router), React 19, Tailwind, componentes acessíveis (Radix/shadcn), gráficos (Recharts).
- Tema escuro/claro, responsivo (cidadão usa muito pelo celular).
- Tempo de carregamento alvo: < 2 s (LCP) no painel do cidadão.
- Atualização em tempo real (staff ao vivo) via WebSocket/SSE alimentado pelo Redis.

## 9. Integração com o jogo (tablets in-game)

Os tablets do jogo (MDT, empresa, facção) **não são o painel web** embutido: são NUI própria, leve, que
consome os mesmos serviços via callbacks do servidor de jogo. Isso evita expor a API ao cliente do jogo
e mantém a performance.
