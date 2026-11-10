# Spec: `spc_hud`

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** UI + Lead Dev · **Fase:** F1 · **Prioridade:** P0

## 1. Elementos
| Elemento | Fonte | Atualização |
|----------|-------|-------------|
| Vida, colete | Natives do ped | A cada 250 ms, **envia à NUI só se mudou** |
| Fome, sede, stress | `LocalPlayer.state.status` (escrito só pelo servidor) | Handler de *state bag* (sem loop) |
| Voz (alcance, falando) | `pma-voice` (`LocalPlayer.state.proximity`, `MumbleIsPlayerTalking`) | 250 ms, só se mudou |
| Rádio (frequência) | `LocalPlayer.state.radioChannel` | Handler de *state bag* |
| Velocímetro (km/h), combustível, cinto | Natives do veículo | 100 ms apenas dentro de veículo |
| Rua e bairro + bússola | `GetStreetNameAtCoord`, `GetLabelText(GetNameOfZone)` | 500 ms, só se mudou |

## 2. Regras
- Escondido durante a seleção de personagem, menu de pausa e câmera de cena (`exports.spc_hud:SetVisible(bool)`).
- Radar mínimo só dentro de veículo (padrão de RP).
- Orçamento cliente: ≤ 0,05 ms a pé, ≤ 0,10 ms em veículo.
- NUI sem framework, mensagens pequenas (`{t:'status', v:{...}}`).

## 3. Critérios de aceite
1. Medido no `resmon` dentro do orçamento.
2. Barras refletem mudanças de status enviadas pelo servidor.
3. Velocímetro só aparece dentro de veículo.
