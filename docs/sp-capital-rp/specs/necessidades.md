# Spec: `spc_needs` — Fome, Sede e Estresse

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Fase:** F2 · **Prioridade:** P0

## 1. Princípio
Status é **autoritativo no servidor**: o servidor calcula, grava no *state bag* `status` (replicado) e o `spc_core`
persiste a cada 5 min. O cliente só exibe (HUD) e aplica efeitos visuais.

## 2. Valores (0–100)
| Status | Padrão (personagem novo) | Decaimento | Zera em |
|--------|--------------------------|------------|---------|
| `hunger` (saciedade) | 100 | −0,55/min | ~3 h reais |
| `thirst` (hidratação) | 100 | −0,83/min | ~2 h reais |
| `stress` | 0 | −1/min quando calmo | — |

- Ciclo do servidor: **a cada 60 s**, todos os personagens carregados, em um único laço (custo O(n), sem queries).
- Em serviço de staff (`staffMode`) ou preso (`jailMinutes > 0`), o decaimento é pausado/reduzido pela metade (preso).

## 3. Efeitos
| Condição | Efeito |
|----------|--------|
| `hunger` ou `thirst` = 0 | −5 de vida por ciclo (evento cliente `spc_needs:client:starve`) |
| `hunger` ou `thirst` < 15 | Aviso no HUD/notificação a cada 5 min |
| `stress` ≥ 60 | Tremor de câmera leve |
| `stress` ≥ 85 | Tremor forte e mira instável |

## 4. Consumo (integração com `ox_inventory`)
Itens com `server.export = 'spc_needs.useItem'`. No evento `usedItem` o servidor aplica o efeito da tabela
(o cliente não informa valores):

| Item | Fome | Sede | Estresse |
|------|------|------|----------|
| `water` | — | +35 | — |
| `soda` | +5 | +25 | −2 |
| `coffee` | — | +10 | −5 |
| `sandwich` | +30 | — | — |
| `pastel` | +35 | −5 | −3 |

## 5. API (exports servidor)
`GetStatus(src)`, `AddStress(src, amount, reason)` (outros sistemas: tiros, perseguição), `SetStatus(src, key, value)`
(staff/hospital; auditado pelo chamador).

## 6. Critérios de aceite
1. Valores decaem no servidor e o HUD reflete sem o cliente enviar números.
2. Comer/beber altera os valores definidos aqui e nada além.
3. Status persiste ao reconectar.
