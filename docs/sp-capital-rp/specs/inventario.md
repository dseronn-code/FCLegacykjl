# Spec: Inventário (`ox_inventory` + ponte `spc`)

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Fase:** F1 · **Prioridade:** P0

## 1. Decisão
Usar o `ox_inventory` (ADR-0002) com uma **ponte de framework própria** (`inventory:framework "spc"`), mantida
em `sp-capital-rp/game/overlays/ox_inventory/` e copiada para a versão fixada do `ox_inventory` pelo script
`infra/scripts/install-overlays.sh`. Não editamos outros arquivos do `ox_inventory`.

## 2. Integração
| Evento do `spc_core` | Ação na ponte |
|----------------------|---------------|
| `spc_core:server:characterLoaded(src, citizenid)` | `setPlayerInventory` com `identifier = characters.id`, nome, gênero, nascimento e grupos |
| `spc_core:server:playerDropped(src)` | `server.playerDropped(src)` (salva e remove o inventário) |
| `spc_core:server:groupsChanged(src, groups)` | Atualiza `inv.player.groups` (empregos/facções, futuras specs) |

- Inventário do jogador: coluna `characters.inventory` (LONGTEXT JSON) — migração 0003.
- Porta-luvas e porta-malas: colunas `vehicles.glovebox` / `vehicles.trunk` — migração 0003 cria a tabela
  `vehicles` mínima (detalhes de veículos virão na spec de veículos/DETRAN).
- Baús (casas, facções, empresas): tabela `ox_inventory` criada pelo próprio recurso.

## 3. Dinheiro
- **Espécie** = item `money` (1 unidade = R$ 1,00). Não há saldo de espécie no `spc_core`; o item é a fonte da verdade.
- **Dinheiro sujo** = item `dirty_money`; não pode ser depositado (spec do banco).
- Conversão banco ↔ espécie só pelo ledger com `CASH_VAULT` ([ledger.md](ledger.md) §6).

## 4. Itens iniciais
Entregues **uma única vez** por personagem, no primeiro carregamento, protegidos por
`UPDATE characters SET starter_items_at = NOW() WHERE id = ? AND starter_items_at IS NULL` (só entrega se 1 linha
afetada): `money` ×500, `phone` ×1, `id_card` ×1 (metadados: nome, RG, CPF, nascimento), `water` ×2, `sandwich` ×2.
(R$ 5.000 do dinheiro inicial ficam no banco; R$ 500 em espécie são parte do kit.)

## 5. Lista de itens (fase 1)
`money`, `dirty_money`, `phone`, `radio`, `id_card`, `driver_license`, `water`, `soda`, `sandwich`, `pastel`,
`coffee`, `bandage`, `medkit`, `lockpick`, `repairkit`, `fuelcan`. Pesos e rótulos em
`sp-capital-rp/game/overlays/ox_inventory/data/items.lua`. Armas usam a lista padrão do `ox_inventory`
(com número de série — exigência do [08-policia.md](../08-policia.md)).

## 6. Segurança
- Configuração `inventory:police` = `["pmc","pciv","prc"]` (revista e evidências).
- Logs de transferência entre jogadores via *hooks* do `ox_inventory` → `spc_logs` (spec de logs de itens, F2).

## 7. Critérios de aceite
1. Personagem novo recebe o kit uma vez; reconectar não duplica.
2. Inventário persiste entre sessões.
3. Reiniciar o `ox_inventory` com jogadores online recarrega os inventários.
