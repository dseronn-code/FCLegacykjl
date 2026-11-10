# Spec: `spc_detran` — Implementação do DETRAN

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Fase:** F2 · **Prioridade:** P1
Regras de negócio: [10-detran.md](../10-detran.md). Esta spec define a implementação.

## 1. Dados
Migração com `licenses`, `driving_exams`, `fines`, `impounds` conforme [02-banco-de-dados.md](../02-banco-de-dados.md).

## 2. Prova teórica
- 20 questões sorteadas de um banco de ≥ 60 (arquivo versionado), 14 acertos para aprovar.
- **O gabarito nunca vai ao cliente**: o cliente recebe só enunciado e alternativas embaralhadas; envia as escolhas;
  o servidor corrige.
- Taxa cobrada antes de começar (`SINK_FEE`, `detran.exam`).

## 3. Prova prática
- *Routing bucket* exclusivo, veículo do DETRAN criado pelo servidor, rota de checkpoints.
- Faltas detectadas no cliente e **reportadas como eventos** (`speeding`, `collision`, `red_light`); o servidor também
  confere velocidade/posição por amostragem (a cada 2 s) e a ordem dos checkpoints. Aprova com ≤ 3 faltas leves e 0 graves.
- Ao fim: entrega o item `driver_license` (metadados: nome, categorias, validade) e grava `licenses`.

## 4. Multas e pontos
Export `IssueFine(target, code, issuerSrc)` usado pela polícia e pelos radares. Pagamento via ledger
(`SINK_FINE`, `fine.pay`). Suspensão automática ao atingir 20 pontos em 30 dias de jogo.

## 5. Exports
`HasLicense(src, type)`, `GetLicenses(citizenid)`, `IssueFine(...)`, `Impound(plate, reason, fee)`.

## 6. Critérios de aceite
1. Cliente modificado não consegue obter o gabarito nem aprovar sem percorrer a rota.
2. CNH aparece no inventário e nas consultas do MDT.
