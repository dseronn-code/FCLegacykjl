-- 0003_inventory_vehicles: suporte ao ox_inventory (ponte spc) e tabela mínima de veículos
-- Spec: docs/sp-capital-rp/specs/inventario.md

ALTER TABLE characters
  ADD COLUMN inventory LONGTEXT NULL COMMENT 'gerenciado pelo ox_inventory' AFTER appearance,
  ADD COLUMN starter_items_at DATETIME NULL AFTER inventory;

-- Versão mínima; colunas de DETRAN (renavam, ipva, licenciamento) virão na spec de veículos.
CREATE TABLE vehicles (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  owner_type  ENUM('character','business','organization','government') NOT NULL,
  owner_id    BIGINT UNSIGNED NOT NULL,
  model       VARCHAR(32) NOT NULL,
  plate       CHAR(7) NOT NULL COMMENT 'Mercosul ABC1D23',
  state       ENUM('garage','out','impound','destroyed','seized') NOT NULL DEFAULT 'garage',
  garage      VARCHAR(32) NULL,
  fuel        TINYINT UNSIGNED NOT NULL DEFAULT 100,
  engine      SMALLINT UNSIGNED NOT NULL DEFAULT 1000,
  body        SMALLINT UNSIGNED NOT NULL DEFAULT 1000,
  mods        JSON NULL,
  mileage_km  INT UNSIGNED NOT NULL DEFAULT 0,
  glovebox    LONGTEXT NULL COMMENT 'ox_inventory',
  trunk       LONGTEXT NULL COMMENT 'ox_inventory',
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_vehicles_plate (plate),
  KEY ix_vehicles_owner (owner_type, owner_id),
  KEY ix_vehicles_state (state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tokens de hardware (token:...) são maiores que 80 caracteres
ALTER TABLE ban_identifiers MODIFY identifier VARCHAR(160) NOT NULL;
