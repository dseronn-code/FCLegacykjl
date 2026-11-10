# 05 — Economia

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Designer de Economia

---

## 1. Objetivos

1. **Dinheiro tem valor.** Um carro bom é uma conquista, uma mansão é um objetivo de meses.
2. **Inflação controlada.** A quantidade de dinheiro por jogador ativo cresce devagar e de forma previsível.
3. **Crime compensa às vezes.** Rende mais que trabalho legal, mas com risco real, custo de lavagem e perdas.
4. **Economia entre jogadores.** Sempre que possível, o dinheiro circula entre jogadores (empresas, serviços)
   em vez de sair de NPCs.

## 2. Moeda

- **Real Capital (R$)**, armazenado em centavos.
- Formas: **dinheiro em espécie** (item `money`, roubável), **conta bancária**, **dinheiro sujo**
  (item `dirty_money`/conta `dirty` de organização, não depositável no banco).

## 3. Curva de referência do jogador

| Marco | Tempo de jogo legal estimado | Valor |
|-------|------------------------------|-------|
| Dinheiro inicial | — | R$ 5.000 (+ celular básico, documento, 1 refeição) |
| Primeira moto usada | ~3 h | R$ 12.000 |
| Carro popular | ~12–15 h | R$ 60.000 |
| Alugar apartamento | ~1 h por semana de aluguel | R$ 3.500/semana |
| Comprar apartamento | ~60 h | R$ 350.000 |
| Carro esportivo | ~150 h | R$ 900.000 |
| Mansão | ~400 h | R$ 3.000.000+ |

## 4. Fontes de dinheiro (*mint*) — onde o dinheiro NASCE

| Fonte | Controle |
|-------|----------|
| Salários de empregos livres (NPC) | Tabela de [04-empregos.md](04-empregos.md), retornos decrescentes |
| Venda de recursos a NPC (peixe, minério, madeira) | **Preço dinâmico**: cai conforme o volume vendido na última hora, se recupera devagar |
| Salários de governo | Pagos pelo cofre do Governo (impostos) — **não é mint**, é redistribuição. Mint só se o cofre estiver abaixo do piso |
| Crimes contra NPC (lojas, bancos) | Valores fixos com cooldown e mínimo de polícia |
| Venda de drogas a NPC | Preço dinâmico por bairro, limite por hora |
| Eventos da staff | Orçamento mensal fixo e logado |

## 5. Drenos (*sinks*) — onde o dinheiro MORRE

| Dreno | Valor de referência |
|-------|---------------------|
| **Imposto de renda** sobre salários NPC/governo | Progressivo 0% (até R$ 3.000/h) / 7,5% / 15% / 22,5% / 27,5% |
| **Imposto sobre transferências** acima de R$ 50 mil (PIX/TED) | 1% |
| **IPVA** (semanal) | 0,5% do valor de tabela do veículo/semana |
| **Licenciamento / seguro** | Seguro opcional: 1%/semana do valor; sem seguro, veículo destruído = perda |
| **IPTU** (semanal) | 0,3% do valor do imóvel/semana |
| **Aluguel de imóveis do governo/NPC** | 100% dreno |
| **Combustível, comida, bebida** | Preços de NPC |
| **Reparos de NPC** (quando não há mecânico online) | +50% sobre preço de referência |
| **Hospital NPC** (sem médicos online) | R$ 4.000 – 15.000 |
| **Multas** | Ver [10-detran.md](10-detran.md) e [08-policia.md](08-policia.md) |
| **Fiança / custas judiciais** | Variável |
| **Pátio do DETRAN** | R$ 1.500 + R$ 500/dia |
| **Lavagem de dinheiro** (perda) | 25–40% |
| **Taxa de plataforma** (app de transporte, Desapega) | 10–20% |
| **Cassino** (vantagem da casa) | ~3–5% |
| **Itens consumíveis e desgaste** | Armas com durabilidade, ferramentas quebram |
| **Licenças** (empresa, porte, CNH) | Ver documentos específicos |

## 6. Preços de referência

| Item | Preço |
|------|-------|
| Água / refrigerante | R$ 8 / R$ 12 |
| Lanche / prato feito | R$ 35 / R$ 60 |
| Combustível (litro) | R$ 7 (tanque ~R$ 350) |
| Celular básico / top | R$ 1.500 / R$ 9.000 |
| Rádio | R$ 2.500 |
| Kit de reparo | R$ 1.800 |
| Pistola legal (com porte) | R$ 25.000 |
| Moto popular | R$ 18.000 |
| Carro popular / sedan / SUV / esportivo / super | R$ 60k / 150k / 350k / 900k / 2,5M |
| Apartamento simples / casa média / mansão | R$ 350k / 1,2M / 3M+ |

## 7. Dinheiro sujo e lavagem

- Crimes geram **dinheiro sujo** (não pode ser depositado; caixas eletrônicos recusam; polícia apreende).
- Lavagem possível via:
  1. **Empresa de fachada** (lavanderia, lava-rápido, restaurante): limite por dia proporcional ao
     faturamento legítimo da empresa (máx. 50% do faturamento declarado) — taxa 25%.
  2. **Doleiro NPC**: rápido, taxa 40%, risco de denúncia (alerta para Polícia Civil).
  3. **Cassino**: taxa ~30%, limite diário.
- Movimentações suspeitas (ex.: empresa fatura 10× a média do setor) geram alertas para a
  **Polícia Civil / Receita** (investigação de RP, não punição automática).

## 8. Monitoramento (dashboard de economia no Grafana/painel)

| Indicador | Cálculo | Meta / gatilho |
|-----------|---------|----------------|
| **M2 por jogador ativo** | (soma de saldos + espécie) / jogadores ativos 7d | Crescimento ≤ 5%/mês |
| **Razão dreno/fonte** | Σ sink / Σ mint (semanal) | 0,85–1,0. < 0,8 → aumentar drenos |
| **Índice de preços (cesta)** | Preço médio entre jogadores de: carro popular usado, refeição em restaurante, reparo, aluguel | ± 5%/mês |
| **Gini** | Concentração de riqueza | Alerta se > 0,75 |
| **Top 1%** | % da riqueza total | Investigação se > 30% |
| **Emissão por personagem/hora** | mint por `citizenid` | Alerta se > R$ 60 mil/h legal ou > R$ 150 mil/h total |
| **Saúde do cofre do Governo** | Saldo da conta do governo | Nunca negativo |

## 9. Governança

- **Revisão mensal** de economia com relatório (dados do ledger) publicado para a staff.
- Mudanças de preço > 15% exigem RFC e aviso à comunidade com 7 dias de antecedência.
- **Sem wipes** planejados. Em caso de exploit, reversão cirúrgica via ledger (por `tx_id`),
  nunca rollback do banco inteiro.
