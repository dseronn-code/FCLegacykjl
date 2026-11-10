# Spec: Ledger Financeiro (`spc_core/ledger`)

**Status:** APROVADO · **Versão:** 1.0 · **Dono:** Lead Dev · **Revisores:** CTO, DBA, Designer de Economia
**Fase:** F1 · **Prioridade:** P0

## 1. Objetivo

Toda movimentação de dinheiro bancário da cidade passa por um único serviço, transacional, idempotente e
auditável, que permite medir exatamente quanto dinheiro foi **criado** (*mint*) e **destruído** (*sink*).

## 2. Conceitos

- **Conta bancária** (`bank_accounts`): pertence a personagem, empresa, organização ou governo. Tem saldo.
- **Conta de sistema**: identificador textual sem saldo armazenado, representa o "mundo fora da economia".
  - `MINT_*`: origem de dinheiro novo (salário NPC, venda a NPC, dinheiro inicial, crime NPC, eventos).
  - `SINK_*`: destino de dinheiro destruído (impostos, lojas NPC, taxas, multas, combustível).
  - `CASH_VAULT`: contrapartida de saque/depósito de dinheiro em espécie (não é *mint* nem *sink*;
    o dinheiro "muda de forma").
- **Transação** (`tx_id`, ULID): um ou mais **movimentos** (*legs*) aplicados de forma atômica.
- **Movimento**: `from → to`, `amount` (centavos, inteiro > 0), `reason`, `ref` opcional. Gera 2 lançamentos
  (débito negativo e crédito positivo) em `ledger_entries`.

Lista de contas de sistema válida fica na config (`Config.SystemAccounts`); qualquer outra é recusada.

## 3. Invariantes

1. Para cada `tx_id`: soma de todos os `amount` = 0.
2. `bank_accounts.balance` = soma dos `amount` da conta em `ledger_entries` (reconciliação diária).
3. Contas bancárias nunca ficam negativas (exceto `kind = 'government'` se `Config.GovernmentCanGoNegative`).
4. Conta `frozen = 1` não pode ser debitada (pode receber).
5. O mesmo `tx_id` nunca é aplicado duas vezes (tabela `ledger_tx` com PK).

## 4. Algoritmo

```
execute(tx):
  validar formato (puro): legs 1..10, amount inteiro 1..10^12, reason ~ ^[a-z_]+\.[a-z_]+$,
                          from != to, contas de sistema conhecidas, ao menos uma conta real no movimento
  START TRANSACTION
    INSERT IGNORE INTO ledger_tx(tx_id, actor, resource) → se 0 linhas: COMMIT e retornar 'duplicate' (sucesso idempotente)
    SELECT id, balance, frozen, kind FROM bank_accounts WHERE id IN (...) ORDER BY id FOR UPDATE
    planejar (puro): aplicar legs em ordem sobre os saldos; recusar se conta inexistente, congelada
                     ou saldo insuficiente → ROLLBACK
    UPDATE bank_accounts SET balance = ? WHERE id = ?   (uma por conta afetada)
    INSERT INTO ledger_entries (...) VALUES (...), (...)  (um único insert multi-linha)
  COMMIT
  publicar log `money.tx` e métricas mint/sink
```

- O bloqueio `FOR UPDATE` em ordem crescente de `id` evita *deadlock* entre transferências cruzadas.
- O "planejamento" é uma função pura (`LedgerCore.plan`) coberta por testes; a camada de banco é fina.

## 5. API (exports do servidor)

| Export | Descrição |
|--------|-----------|
| `Execute({txId?, actor?, legs})` | Executa transação genérica. Retorna `ok, result` (`result.txId`, `result.duplicate`) ou `false, errorCode` |
| `Transfer(fromAccountId, toAccountId, amount, reason, ref?)` | Atalho para 1 movimento entre contas reais (ex.: PIX) |
| `Pay(src, amount, mintAccount, reason, ref?)` | Credita o personagem ativo a partir de uma conta `MINT_*` ou de uma conta real (ex.: governo) |
| `Charge(src, amount, sinkAccount, reason, ref?)` | Debita o personagem ativo para uma conta `SINK_*` ou real |
| `GetBalance(accountId)` | Saldo atual (consulta direta) |

`actor` padrão: `char:<citizenid>` quando há `src`, senão `system`. O recurso chamador
(`GetInvokingResource()`) é gravado em `ledger_tx.resource` — permite auditar qual script emitiu dinheiro.

Códigos de erro: `invalid_tx`, `invalid_amount`, `invalid_reason`, `invalid_account`, `same_account`,
`account_not_found`, `account_frozen`, `insufficient_funds`, `player_not_loaded`, `db_error`.

## 6. Dinheiro em espécie

Espécie é o item `money` do `ox_inventory`. Saque e depósito (caixa eletrônico/agência) usam o ledger com
`CASH_VAULT`:

- **Saque:** ledger (conta → `CASH_VAULT`, `cash.withdraw`) **e então** adiciona o item. Se o item não couber
  no inventário, executa a transação inversa (`cash.withdraw_revert`).
- **Depósito:** remove o item **e então** ledger (`CASH_VAULT` → conta, `cash.deposit`). Se o ledger falhar,
  devolve o item.

A implementação de saque/depósito pertence ao recurso do banco (`spc_bank`, spec futura); o core fornece
apenas o ledger.

## 7. Banco de dados

- `ledger_tx (tx_id PK, actor, resource, created_at)` — idempotência, não particionada.
- `ledger_entries` particionada por mês (`RANGE COLUMNS(created_at)`), PK `(id, created_at)`.
  Um worker cria a partição do mês seguinte no dia 20 de cada mês.
- Consulta de reconciliação: `sp-capital-rp/packages/db/queries/reconcile.sql`.

## 8. Segurança

- Não existe evento de rede que mova dinheiro. Apenas exports do servidor, chamados por recursos do servidor
  após validar a ação de jogo.
- Alertas (via `spc_logs` → Grafana): mint por personagem > R$ 60 mil/h (legal) ou > R$ 150 mil/h (total);
  qualquer movimento > R$ 1 milhão; recursos emitindo de contas `MINT_*` fora da allowlist do recurso.
- Reversão por staff: nova transação com movimentos invertidos e `reason = 'staff.revert'`, `ref = tx original`.
  Nunca se apagam lançamentos.

## 9. Critérios de aceite

1. Testes puros: validação, planejamento, saldo insuficiente, conta congelada, múltiplos movimentos, soma zero.
2. Reaplicar o mesmo `txId` não altera saldos.
3. Migração cria as tabelas e a consulta de reconciliação retorna 0 divergências após transações de teste.
