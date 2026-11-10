# Spec: Whitelist e Fila (`spc_queue` + bot)

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev + Dev Web · **Revisores:** CTO, Head de Staff
**Fase:** F1 (whitelist) / F3 (fila com prioridade) · **Prioridade:** P0

## 1. Whitelist (fonte da verdade: banco)

1. O bot coleta o formulário e grava `whitelist_applications` (`pending`).
2. Staff revisa no painel → `interview` → entrevista por voz → `approved` ou `rejected`.
3. Na aprovação, a API cria/atualiza `accounts` (`discord_id`, `whitelist_status = 'approved'`) e publica o
   comando `account.refresh` para o jogo. O bot dá o cargo `Cidadão`.
4. O servidor de jogo **nunca** consulta a API do Discord: só o banco (com cache do `spc_core`).

Estados de `whitelist_applications.status`: `pending → interview → approved | rejected`.
Reprovação: nova tentativa liberada após 7 dias (`retry_after`).

## 2. Fila (F3, antes do beta de 250 jogadores)

- Implementada nos *deferrals*, **depois** das verificações do `spc_core` (ban/whitelist).
- Ordem: `accounts.priority` (0–100) desc, depois horário de entrada na fila.
- Fontes de prioridade (a maior vale, não somam): staff 100, instituições em escala do dia 60,
  apoiador (Tebex) 10–30, padrão 0.
- **Anti-abuso:** prioridade de apoiador nunca passa à frente de instituições; reconexão em até 5 min após
  queda mantém a posição ("graça de reconexão").
- Cartão adaptativo mostra posição, tempo estimado e botão do Discord.
- Slots reservados: 16 para staff e emergência (não entram na fila pública).

## 3. Critérios de aceite
1. Jogador aprovado no painel consegue entrar em até 10 s após a aprovação (sem reiniciar o servidor).
2. Jogador reprovado ou suspenso é derrubado ao receber `account.refresh`.
3. (F3) Com servidor cheio, a ordem da fila respeita prioridade e graça de reconexão.
