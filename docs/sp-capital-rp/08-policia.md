# 08 — Polícia

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev + Comando da Polícia

---

## 1. Corporações (todas fictícias)

| Corporação | Sigla | Função | Efetivo-alvo (500 CCU) |
|------------|-------|--------|------------------------|
| **Polícia Militar da Capital** | PMC | Patrulhamento ostensivo, atendimento 190, abordagens, flagrante | 40–60 em serviço |
| ↳ Grupo Tático de Intervenção | GTI | Ações de alto risco, reféns, roubos a banco | 8–12 |
| ↳ Policiamento de Trânsito | BPTran | Blitz, fiscalização, acidentes | 4–6 |
| ↳ Aviação ("Águia") | GRPAe | Helicóptero | 2 |
| **Polícia Civil da Capital** | PCiv | Investigação, inquéritos, mandados, delegacias, perícia | 10–15 |
| ↳ Perícia | IC | Coleta e análise de evidências | 2–3 |
| **Polícia Rodoviária da Capital** | PRC | Rodovias, interior, cargas | 4–6 |
| **Sistema Prisional** | SAP | Presídio, escolta de presos | 2–4 |

## 2. Hierarquia (PMC — exemplo)

| Grau | Patente | Permissões |
|------|---------|------------|
| 1 | Soldado 2ª Classe (estágio) | Patrulha acompanhado, multas leves |
| 2 | Soldado | Patrulha, prisão em flagrante |
| 3 | Cabo | Comanda viatura |
| 4 | 3º Sargento / 2º / 1º | Supervisão de área, uso de fuzil |
| 5 | Subtenente | Coordenação de turno |
| 6 | Tenente / Capitão | Comando de operações, recrutamento |
| 7 | Major / Tenente-Coronel | Comando de batalhão |
| 8 | Coronel (Comandante-Geral) | Gestão completa (cargo de confiança da staff) |

PCiv: Investigador → Escrivão → Perito → Delegado → Delegado-Geral.

## 3. Ingresso e carreira

1. Inscrição no painel (requisitos: 20 h de cidade, sem ban nos últimos 30 dias, ficha limpa do personagem).
2. Prova teórica (regulamento, código penal da cidade, Código Q).
3. **Academia** (curso prático com instrutores): abordagem, perseguição, tiro, uso progressivo da força.
4. Estágio probatório de 14 dias.
5. Promoções por tempo + avaliação + cursos (GTI, aviação, trânsito).

## 4. Ferramentas

### 4.1 MDT (tablet policial — NUI)
- Consulta de pessoa (por nome/RG/CPF): foto, CNH, porte, multas, mandados, antecedentes.
- Consulta de veículo (placa): dono, situação (roubado, IPVA atrasado, apreendido).
- Boletins de ocorrência, relatórios de prisão, inquéritos (PCiv), mandados (pedido ao juiz).
- **Painel de unidades**: quem está em serviço, viatura, status (Código Q), localização.
- Código penal integrado: o policial seleciona os artigos e o sistema calcula pena e multa.

### 4.2 Despacho
- Chamadas 190 pelo celular (com localização aproximada).
- Alertas automáticos de crimes (com atraso e imprecisão configuráveis: o crime não "aparece no mapa" na hora).
- Botão de pânico (vermelho no mapa de todos os policiais).

### 4.3 Equipamentos
- Armário de armas por patente (armas com número de série registrado na corporação, devolução obrigatória ao sair de serviço).
- Algemas, taser, spike strip, cones, radar de velocidade, bafômetro, câmera corporal (log de eventos).
- Viaturas por patente/divisão; garagem da corporação (sem custo para o policial, mas com log de uso e dano).

### 4.4 Radares (ANPR)
- Radares fixos em vias principais registram placas: veículos com alerta (roubado, mandado) notificam o despacho.
- Fotossensores de velocidade geram multas automáticas (ver [10-detran.md](10-detran.md)).

## 5. Código Q (comunicação por rádio)

| Código | Significado |
|--------|-------------|
| QAP | Na escuta |
| QSL | Entendido |
| QTH | Localização |
| QRU | Ocorrência / tem algo para mim? |
| QRV | À disposição |
| QTA | Cancelar |
| QRX | Aguarde |
| QTR | Horário |
| J1–J5 | Status de deslocamento (convenção interna) |
| Código 0 | Policial em perigo (prioridade máxima) |

## 6. Prisão e pena

- **Código Penal da Cidade** (documento à parte, público): cada artigo tem pena em **meses** e multa.
- Conversão: **1 mês = 1 minuto** de prisão real (pena máxima: 120 minutos por condenação; acima → julgamento).
- Fluxo: abordagem → algemar → revista (apreensão de itens) → delegacia → registro no MDT →
  advogado (opcional, pode reduzir pena por acordo) → presídio.
- **Presídio:** instanciado; trabalhos internos reduzem pena (1 tarefa = −1 min, máx. −30%);
  fuga possível como evento raro com regras.
- **Fiança:** crimes leves permitem fiança (paga ao Governo = dreno).
- Pena > 60 meses ou crime hediondo → **julgamento** com juiz/promotor (se houver online; senão, pena padrão).
- Desconectar algemado ou preso = **pena dobrada automática** + advertência (anti-*combat log*).

## 7. Evidências e investigação

| Evidência | Origem | Revela |
|-----------|--------|--------|
| Cápsula | Disparo de arma | Número de série / tipo de arma |
| Sangue | Ferimento | DNA → personagem (análise em laboratório leva tempo) |
| Digital | Arrombamento, volante | Personagem (se sem luvas) |
| Câmeras de segurança | Lojas/bancos | Roupa, veículo e placa aproximados |
| Ligações / mensagens | Mandado judicial | Histórico do celular do suspeito |

- Cadeia de custódia registrada (quem coletou, quem analisou).
- Inquérito → mandado de busca/prisão → operação. Recompensa: bônus para a equipe e perda de influência
  territorial da facção investigada.

## 8. Regras de conduta (resumo)

- Uso progressivo da força: verbalização → contenção → não letal → letal.
- Proibido: corrupção sem RP aprovado, abuso de autoridade fora de RP, usar o MDT para metagaming.
- **Bodycam obrigatória** (log automático de ações) — usada pela Corregedoria em denúncias.
- Corregedoria (staff + oficiais designados) analisa denúncias pelo painel.

## 9. Métricas da instituição

- Policiais em serviço por horário (meta: ≥ 10 em qualquer horário com > 150 jogadores).
- Tempo médio de resposta ao 190.
- Taxa de esclarecimento de crimes.
- Denúncias procedentes contra policiais.
