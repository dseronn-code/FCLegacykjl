# Spec: `spc_bank` — Banco Capital (agências, caixas e PIX)

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev + Designer de Economia · **Fase:** F2 · **Prioridade:** P0

## 1. Operações
| Operação | Onde | Limite | Ledger |
|----------|------|--------|--------|
| Saldo e extrato (últimos 20 lançamentos) | Caixa, agência, celular | — | leitura |
| Saque | Caixa: até R$ 2.000/operação · Agência: até R$ 50.000 | Caixa: R$ 10.000/dia por personagem (dia UTC) | conta → `CASH_VAULT` (`atm.withdraw` no caixa, `cash.withdraw` na agência) + item `money` |
| Depósito | Agência (caixa só deposita até R$ 2.000) | — | item `money` → `CASH_VAULT` → conta (`cash.deposit`) |
| PIX | Caixa, agência, celular | R$ 100.000/operação | conta → conta (`pix.send`); acima de R$ 50.000, 1% para `SINK_TAX` (`tax.transfer`) na mesma transação |

- **Chave PIX** = telefone do personagem (`(11) 9XXXX-XXXX`). Chaves customizadas: fase posterior.
- **Dinheiro sujo** (`dirty_money`) nunca é aceito: o depósito só retira o item `money` do inventário.
- Valores sempre inteiros em reais na interface; convertidos para centavos no servidor (item `money`: 1 unidade = R$ 1).

## 2. Validação no servidor
- Proximidade: agência — o servidor confere a distância do ped à lista de coordenadas (≤ 3 m).
  Caixa eletrônico — os caixas são objetos do mapa, não sincronizados com o servidor; na versão alpha o servidor
  confere a distância até a posição informada pelo cliente. **Limitação conhecida:** um cliente modificado poderia
  usar um caixa à distância (impacto limitado pelos limites de R$ 2.000/operação e R$ 10.000/dia). Uma lista fixa de
  caixas será levantada no staging para fechar essa brecha.
- Rate limit: 1 operação a cada 2 s por jogador.
- Saque: ledger **antes** de entregar o item; se o item não couber, transação inversa (`cash.withdraw_revert`).
- Depósito: remove o item **antes** do ledger; se o ledger falhar, devolve o item.
- PIX para si mesmo é recusado; destino inexistente → `pix_key_not_found`.

## 3. Interface (alpha)
Menus `ox_lib` (contexto + diálogos). NUI própria do banco e app no celular vêm com a spec do celular.

## 4. Logs
`bank.withdraw`, `bank.deposit`, `bank.pix`, `bank.limit_reached` — além do `money.tx` do ledger.

## 5. Critérios de aceite
1. Saque e depósito mantêm a soma (banco + espécie) constante e o ledger reconciliado.
2. Limites diários respeitados entre reconexões (contados no ledger do dia).
3. Falha no inventário não cria nem destrói dinheiro.
