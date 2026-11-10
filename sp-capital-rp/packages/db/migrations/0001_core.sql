-- 0001_core: contas, personagens, staff, bans, whitelist e auditoria
-- Spec: docs/sp-capital-rp/specs/spc_core.md · docs/sp-capital-rp/02-banco-de-dados.md

CREATE TABLE accounts (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  discord_id       VARCHAR(32)  NOT NULL,
  license          VARCHAR(64)  NULL,
  license2         VARCHAR(64)  NULL,
  fivem_id         VARCHAR(64)  NULL,
  steam_id         VARCHAR(64)  NULL,
  whitelist_status ENUM('pending','approved','rejected','suspended') NOT NULL DEFAULT 'pending',
  char_slots       TINYINT UNSIGNED NOT NULL DEFAULT 2,
  priority         TINYINT UNSIGNED NOT NULL DEFAULT 0,
  playtime_minutes INT UNSIGNED NOT NULL DEFAULT 0,
  last_login_at    DATETIME NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounts_discord (discord_id),
  UNIQUE KEY uq_accounts_license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE characters (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  citizenid     CHAR(8)      NOT NULL,
  account_id    BIGINT UNSIGNED NOT NULL,
  first_name    VARCHAR(32)  NOT NULL,
  last_name     VARCHAR(32)  NOT NULL,
  birthdate     DATE         NOT NULL,
  gender        ENUM('m','f','x') NOT NULL,
  nationality   VARCHAR(32)  NOT NULL DEFAULT 'Brasileira',
  cpf           CHAR(14)     NOT NULL,
  rg            VARCHAR(12)  NOT NULL,
  phone_number  VARCHAR(16)  NOT NULL,
  appearance    JSON         NULL,
  position      JSON         NULL,
  status        JSON         NULL,
  is_dead       TINYINT(1)   NOT NULL DEFAULT 0,
  jail_minutes  INT UNSIGNED NOT NULL DEFAULT 0,
  last_played_at DATETIME    NULL,
  ck_at         DATETIME     NULL,
  deleted_at    DATETIME     NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_characters_citizenid (citizenid),
  UNIQUE KEY uq_characters_cpf (cpf),
  UNIQUE KEY uq_characters_rg (rg),
  UNIQUE KEY uq_characters_phone (phone_number),
  KEY ix_characters_account (account_id),
  CONSTRAINT fk_characters_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE staff (
  account_id   BIGINT UNSIGNED NOT NULL,
  role         ENUM('helper','mod','admin','head','dev','owner') NOT NULL,
  totp_secret  VARBINARY(255) NULL COMMENT 'criptografado pela API',
  active       TINYINT(1) NOT NULL DEFAULT 1,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (account_id),
  CONSTRAINT fk_staff_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE bans (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id  BIGINT UNSIGNED NULL,
  reason      VARCHAR(255) NOT NULL,
  staff_account_id BIGINT UNSIGNED NULL,
  expires_at  DATETIME NULL COMMENT 'NULL = permanente',
  revoked_at  DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_bans_account (account_id),
  CONSTRAINT fk_bans_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Identificadores banidos (license:, license2:, discord:, fivem:, steam:) — busca indexada na conexão
CREATE TABLE ban_identifiers (
  ban_id      BIGINT UNSIGNED NOT NULL,
  identifier  VARCHAR(80) NOT NULL,
  PRIMARY KEY (ban_id, identifier),
  KEY ix_ban_identifiers_identifier (identifier),
  CONSTRAINT fk_ban_identifiers_ban FOREIGN KEY (ban_id) REFERENCES bans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE warnings (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id  BIGINT UNSIGNED NOT NULL,
  reason      VARCHAR(255) NOT NULL,
  points      TINYINT UNSIGNED NOT NULL DEFAULT 1,
  staff_account_id BIGINT UNSIGNED NULL,
  expires_at  DATETIME NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_warnings_account (account_id, expires_at),
  CONSTRAINT fk_warnings_account FOREIGN KEY (account_id) REFERENCES accounts (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE whitelist_applications (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  discord_id    VARCHAR(32) NOT NULL,
  answers       JSON NOT NULL,
  status        ENUM('pending','interview','approved','rejected') NOT NULL DEFAULT 'pending',
  reviewer_account_id BIGINT UNSIGNED NULL,
  interview_at  DATETIME NULL,
  retry_after   DATETIME NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_whitelist_discord (discord_id),
  KEY ix_whitelist_status (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_log (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  staff_account_id BIGINT UNSIGNED NULL,
  action           VARCHAR(64) NOT NULL,
  target           VARCHAR(80) NULL,
  before_data      JSON NULL,
  after_data       JSON NULL,
  ip               VARCHAR(45) NULL,
  created_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_audit_staff (staff_account_id, created_at),
  KEY ix_audit_target (target)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
