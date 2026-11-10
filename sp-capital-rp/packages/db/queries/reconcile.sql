-- Reconciliação diária: contas cujo saldo diverge da soma do ledger (esperado: 0 linhas)
SELECT b.id, b.number, b.balance, COALESCE(SUM(e.amount), 0) AS ledger_sum
FROM bank_accounts b
LEFT JOIN ledger_entries e ON e.account_id = b.id
GROUP BY b.id, b.number, b.balance
HAVING b.balance <> COALESCE(SUM(e.amount), 0);

-- Transações que não somam zero (esperado: 0 linhas)
SELECT tx_id, SUM(amount) AS total
FROM ledger_entries
GROUP BY tx_id
HAVING SUM(amount) <> 0;
