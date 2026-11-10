# 04 — Empregos

**Status:** EM REVISÃO · **Versão:** 0.1 · **Dono:** Designer de Economia + Lead Dev

---

## 1. Filosofia

- **Todo novato precisa de um caminho claro** para ganhar dinheiro legalmente nas primeiras 2 horas.
- **Progressão:** quanto mais você trabalha numa profissão, mais ganha (níveis 1–10).
- **Interação humana > grind solo:** empregos que envolvem outros jogadores pagam mais.
- **Anti-farm:** retornos decrescentes após muitas horas contínuas; validação server-side de cada tarefa.

## 2. Categorias

| Categoria | Acesso | Exemplos |
|-----------|--------|----------|
| **Livres (NPC)** | Qualquer um, pela Agência de Empregos (app ou prédio no Centro) | Entregador, gari, caminhoneiro, motorista de ônibus, pescador |
| **Com requisito** | Licença ou curso | Taxista/app (CNH B), caminhoneiro pesado (CNH E), piloto (licença), segurança (curso + porte) |
| **Empresas de jogadores** | Contratação pelo dono | Mecânico, cozinheiro, vendedor, barman — ver [07-empresas.md](07-empresas.md) |
| **Governo (whitelist)** | Processo seletivo | Polícia, médicos, bombeiros, DETRAN, justiça, prefeitura |

## 3. Tabela de empregos livres (valores de referência em R$/hora efetiva — ver economia)

| Emprego | Requisito | R$/h nível 1 | R$/h nível 10 | Mecânica | Interação |
|---------|-----------|-------------|--------------|----------|-----------|
| **Entregador de moto ("Rapidinho")** | Nenhum (moto alugada) | 3.500 | 6.000 | Rotas de entrega com tempo; pedidos de comida reais de jogadores dão bônus | Média |
| **Gari** | Nenhum | 3.200 | 5.500 | Caminhão com 2–4 pessoas; coleta por ponto; bônus por equipe | Alta |
| **Motorista de ônibus (SPTrans-like → "CapTrans")** | CNH D (nível 1 pode com B em linha curta) | 4.000 | 7.000 | Linhas fixas, NPCs e jogadores pagam passagem | Média |
| **Taxista / Motorista de app ("Leva")** | CNH B | variável | variável | Corridas de NPC + chamadas de jogadores pelo celular (taxa 20% para a plataforma = dreno) | Alta |
| **Caminhoneiro** | CNH C/E | 5.000 | 9.000 | Cargas Porto ↔ interior; risco de roubo de carga | Média |
| **Pescador** | Licença de pesca | 2.500 | 5.000 | Minigame, venda no mercado de peixe (preço dinâmico) | Baixa |
| **Lenhador / Madeireira** | Nenhum | 3.000 | 5.500 | Cortar, transportar, vender à serraria | Baixa |
| **Mineração** | Nenhum | 3.000 | 6.000 | Minérios → fundição; insumo para crafting | Baixa |
| **Agricultor** | Nenhum | 2.800 | 5.000 | Plantio/colheita, abastece restaurantes | Baixa |
| **Eletricista / Técnico ("Eletropaulo" → "CapEnergia")** | Curso | 4.500 | 8.000 | Reparos em pontos da cidade; restaurar energia após apagão (evento) | Média |
| **Segurança privado** | Curso + porte | 4.500 | 7.500 | Escolta de carro-forte (NPC), segurança de eventos | Alta |
| **Guincho** | CNH C | 4.000 | 7.000 | Chamadas de jogadores e pátio do DETRAN | Alta |
| **Jornalista** | Contratação | variável | variável | Matérias, fotos; pago por publicação aprovada | Alta |

> Valores são **teto de renda média** com execução eficiente; o balanceamento final fica em
> `packages/shared/economy/jobs.json` e é ajustado mensalmente.

## 4. Empregos de governo (salário fixo + bônus)

| Instituição | Salário-base (R$/h em serviço) | Faixa por patente | Bônus |
|-------------|-------------------------------|-------------------|-------|
| Polícia Militar | 5.000 | 5.000 – 12.000 | Prisão concluída, apreensão |
| Polícia Civil | 5.500 | 5.500 – 12.000 | Inquérito concluído |
| Médicos / SAMU | 5.500 | 5.500 – 13.000 | Por atendimento (cobrado do paciente) |
| Bombeiros | 5.000 | 5.000 – 11.000 | Incêndio/resgate |
| DETRAN | 4.500 | 4.500 – 9.000 | Exames aplicados |
| Juiz / Promotor | 8.000 | 8.000 – 15.000 | Por audiência |

- Pago **a cada 15 min em serviço ativo** (detecção de AFK: sem movimento/ação por 10 min = pausa).
- Limite de pagamento: 8 h de serviço/dia por personagem.
- Salário sai da **conta do Governo**, que é abastecida pelos impostos (ver economia). Se o governo
  "quebrar", isso é sinal de desequilíbrio e dispara alerta para o designer de economia.

## 5. Progressão

- XP por tarefa concluída; níveis 1–10. Nível destrava: rotas melhores, veículos melhores, bônus de pagamento.
- XP decai 5%/semana sem trabalhar (manter atividade, não punir demais).
- Certificados (item/documento) comprovam experiência para contratação em empresas.

## 6. Anti-farm e validação

| Regra | Valor |
|-------|-------|
| Retorno decrescente | Após 3 h contínuas no mesmo emprego: −20%; após 5 h: −40% |
| Validação | Server valida distância do ponto, tempo mínimo entre tarefas, veículo correto |
| Multi-conta | Mesma tarefa por 2 personagens da mesma conta no mesmo dia: bloqueado |
| Velocidade anormal | Tarefas concluídas mais rápido que o mínimo humano → alerta anticheat |
| AFK | Sem pagamento após 10 min sem ação |

## 7. Spec mínima por emprego (template)

Cada emprego terá `docs/specs/jobs/<nome>.md` contendo: objetivo de RP, fluxo passo a passo,
locais (coordenadas), itens/veículos, pagamentos por tarefa, XP, validações, eventos server/client,
logs gerados, orçamento de performance e critérios de aceite.
