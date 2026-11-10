-- 0002_bank_ledger: contas bancárias e livro-razão de dupla entrada
-- Spec: docs/sp-capital-rp/specs/ledger.md

CREATE TABLE bank_accounts (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  number      VARCHAR(12) NOT NULL,
  owner_type  ENUM('character','business','organization','government') NOT NULL,
  owner_id    BIGINT UNSIGNED NOT NULL,
  kind        ENUM('checking','savings','salary','business','dirty','government') NOT NULL,
  balance     BIGINT NOT NULL DEFAULT 0 COMMENT 'centavos; cache do ledger, reconciliado diariamente',
  pix_key     VARCHAR(64) NULL,
  frozen      TINYINT(1) NOT NULL DEFAULT 0,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bank_accounts_number (number),
  UNIQUE KEY uq_bank_accounts_pix (pix_key),
  KEY ix_bank_accounts_owner (owner_type, owner_id, kind),
  CONSTRAINT ck_bank_balance CHECK (balance >= 0 OR kind = 'government')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Idempotência: uma linha por transação. Não particionada para permitir PK em tx_id.
CREATE TABLE ledger_tx (
  tx_id       CHAR(26) NOT NULL,
  actor       VARCHAR(48) NOT NULL,
  resource    VARCHAR(64) NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (tx_id),
  KEY ix_ledger_tx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ledger_entries (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tx_id           CHAR(26) NOT NULL,
  leg             TINYINT UNSIGNED NOT NULL,
  account_id      BIGINT UNSIGNED NULL COMMENT 'NULL = conta de sistema',
  system_account  VARCHAR(32) NULL,
  amount          BIGINT NOT NULL COMMENT '+ crédito / - débito (centavos)',
  balance_after   BIGINT NULL,
  reason          VARCHAR(48) NOT NULL,
  ref_type        VARCHAR(32) NULL,
  ref_id          VARCHAR(64) NULL,
  actor           VARCHAR(48) NOT NULL,
  created_at      DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id, created_at),
  KEY ix_ledger_account (account_id, created_at),
  KEY ix_ledger_tx (tx_id),
  KEY ix_ledger_reason (reason, created_at),
  KEY ix_ledger_system (system_account, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
PARTITION BY RANGE COLUMNS (created_at) (
  PARTITION p2026_11 VALUES LESS THAN ('2026-12-01'),
  PARTITION p2026_12 VALUES LESS THAN ('2027-01-01'),
  PARTITION p2027_01 VALUES LESS THAN ('2027-02-01'),
  PARTITION p2027_02 VALUES LESS THAN ('2027-03-01'),
  PARTITION p2027_03 VALUES LESS THAN ('2027-04-01'),
  PARTITION pmax     VALUES LESS THAN (MAXVALUE)
);

-- Conta do Governo (paga salários públicos; recebe impostos e multas)
INSERT INTO bank_accounts (number, owner_type, owner_id, kind, balance)
VALUES ('0001-000001', 'government', 1, 'government', 0);
