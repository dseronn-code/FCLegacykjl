# Spec: API mínima e Bot de Whitelist

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Dev Web · **Fase:** F1 · **Prioridade:** P0

## 1. Objetivo
Fechar o ciclo **Discord → whitelist → entrada na cidade** sem acesso manual ao banco.

## 2. API (`services/api`, Fastify + TypeScript)
Autenticação **de serviço** (F1): cabeçalho `Authorization: Bearer <SPC_API_TOKEN>`, rede privada.
Login de staff via Discord OAuth2 + 2FA é do painel (F2). Ações de staff vindas do bot informam
`staffDiscordId`; a API **confere na tabela `staff`** se esse Discord tem o papel exigido.

| Método e rota | Uso | Regras |
|---------------|-----|--------|
| `GET /health` | Monitoramento | Sem auth |
| `POST /v1/whitelist/applications` | Bot envia formulário | `discordId`, `answers` (objeto, máx. 8 KB). Recusa se há pedido `pending`/`interview`, se a conta já é `approved`, ou se `retry_after` está no futuro |
| `GET /v1/whitelist/applications?status=pending` | Bot lista fila | `staffDiscordId` com `whitelist.review` |
| `POST /v1/whitelist/applications/:id/interview` | Marca para entrevista | `whitelist.review` |
| `POST /v1/whitelist/applications/:id/approve` | Aprova | `whitelist.review`; cria/atualiza `accounts` (`approved`) numa transação; publica `account.refresh` assinado |
| `POST /v1/whitelist/applications/:id/reject` | Reprova | `whitelist.review`; `retry_after = agora + 7 dias`; motivo obrigatório |
| `GET /v1/server/status` | `/status` do bot | Jogadores online (contagem de sessões via evento `spc:evt` agregado no Redis) |

- Toda ação de staff grava `audit_log`.
- Comandos ao jogo usam o protocolo de [logs-e-bridge.md](logs-e-bridge.md) (envelope `body` + `sig`).
- Validação de entrada com Zod; erros no formato `{ error: "<codigo>" }`.

Papéis exigidos usam a mesma tabela de permissões do jogo (`packages/shared/permissions.json`, gerado a partir
da config do `spc_core` — fonte única).

## 3. Bot (`apps/discord-bot`, discord.js v14)
| Interação | Comportamento |
|-----------|---------------|
| Mensagem fixa em `#formulário` com botão **Fazer whitelist** | Abre *modal* com 5 campos: idade, experiência em RP, nome e história do personagem, o que é "amor à vida", o que é metagaming |
| Envio do modal | `POST /v1/whitelist/applications`; resposta efêmera; publica cartão em `#revisão-whitelist` com botões **Entrevista**, **Aprovar**, **Reprovar** |
| Botões de revisão | Chamam a API com `staffDiscordId` do clicador; **Reprovar** abre modal de motivo; o cartão é atualizado com o resultado |
| Aprovação | Bot dá o cargo `Cidadão` e envia DM ao jogador |
| `/status` | Jogadores online e status do servidor |
| Conta Discord com < 30 dias | Cartão recebe aviso "conta recente" para revisão extra |

Configuração por variáveis de ambiente: `DISCORD_TOKEN`, `DISCORD_GUILD_ID`, `CHANNEL_FORM_ID`,
`CHANNEL_REVIEW_ID`, `ROLE_CITIZEN_ID`, `SPC_API_URL`, `SPC_API_TOKEN`.

## 4. Critérios de aceite
1. Jogador envia formulário pelo Discord; staff aprova pelo botão; jogador entra na cidade sem reinício.
2. Clique de quem não está na tabela `staff` é recusado.
3. Pedido duplicado ou dentro do prazo de nova tentativa é recusado.
4. Testes da API contra MariaDB e Redis reais.
