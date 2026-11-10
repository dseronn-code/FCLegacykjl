# Spec: `spc_admin` — Ferramentas de Staff no Jogo

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev + Head de Staff · **Fase:** F1 · **Prioridade:** P0

## 1. Princípios
- Toda ação exige permissão (`exports.spc_core:HasPermission`) **verificada no servidor**.
- Toda ação é gravada em `audit_log` (MariaDB) **e** em `spc_logs` (`admin.*`).
- Ações que afetam outro jogador exigem **motivo** (mín. 5 caracteres).
- Staff precisa estar **em modo staff** (`/staff`) para usar noclip, invisibilidade e teleporte; o modo staff
  aparece para outros staff (state bag `staffMode`) e é logado.

## 2. Comandos
| Comando | Permissão | Efeito |
|---------|-----------|--------|
| `/staff` | `players.read` | Liga/desliga modo staff |
| `/kick <id> <motivo>` | `players.kick` | Derruba |
| `/warn <id> <pontos 1-3> <motivo>` | `warnings.write` | Advertência (expira em 60 dias) |
| `/ban <id> <horas \| perm> <motivo>` | `bans.temp` (até 72 h) / `bans.write` (qualquer, inclusive permanente) | Grava `bans` + todos os identificadores do jogador em `ban_identifiers`, derruba |
| `/unban <banId> <motivo>` | `bans.write` | Define `revoked_at` |
| `/tp <id>` · `/bring <id>` · `/tpm` (marcador) | `players.teleport` | Teleporte (só em modo staff) |
| `/noclip` | `players.teleport` | Alterna noclip (cliente, só em modo staff) |
| `/spec <id>` | `players.spectate` | Observa o jogador (servidor fornece coordenadas; cliente usa *routing* do OneSync) |
| `/reviver <id>` | `players.revive` | Evento `spc_admin:revive` (o sistema de hospital tratará; até lá, ressuscita o ped) |
| `/coords` | `players.read` | Mostra coordenadas (útil para mapeamento) |

## 3. Regras de ban
- Duração: `perm` ou 1–8760 horas. Moderador (`bans.temp`) limitado a 72 h.
- Identificadores gravados: todos os `license`, `license2`, `discord`, `fivem`, `steam` do jogador no momento
  do ban, mais os *tokens* de hardware (`GetPlayerTokens`) — gravados como `token:<valor>`.
- O `spc_core` passa a verificar também os tokens na conexão.
- Staff não pode banir papel igual ou superior ao seu.

## 4. Critérios de aceite
1. Comando sem permissão é recusado e logado como `permission.denied`.
2. Ban grava todos os identificadores e impede a reconexão (inclusive com outra conta Discord no mesmo PC).
3. Toda ação aparece em `audit_log` com antes/depois quando aplicável.
