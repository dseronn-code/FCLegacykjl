-- Dinheiro criado (MINT_*) e destruído (SINK_*) por dia e conta de sistema
SELECT DATE(created_at) AS dia, system_account,
       SUM(-amount) AS valor_centavos   -- lançamento de sistema tem sinal oposto ao da conta real
FROM ledger_entries
WHERE system_account IS NOT NULL
  AND created_at >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY dia, system_account
ORDER BY dia DESC, system_account;
