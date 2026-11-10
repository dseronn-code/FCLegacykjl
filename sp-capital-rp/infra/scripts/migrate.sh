#!/usr/bin/env bash
# Aplica migrações pendentes em ordem e registra em schema_migrations.
# Uso: DB_NAME=spcapital MYSQL="mariadb -uroot" ./migrate.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")/../../packages/db/migrations" && pwd)"
DB_NAME="${DB_NAME:-spcapital}"
MYSQL="${MYSQL:-mariadb}"
SQL() { $MYSQL "$DB_NAME" -N -B -e "$1"; }

$MYSQL -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
SQL "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(64) PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)"

for f in "$DIR"/*.sql; do
  v="$(basename "$f" .sql)"
  if [ -n "$(SQL "SELECT 1 FROM schema_migrations WHERE version='$v'")" ]; then
    echo "= $v (já aplicada)"; continue
  fi
  echo "+ $v"
  # DDL no MariaDB faz commit implícito: cada migração deve ser segura para reexecutar após falha parcial
  # ou ser corrigida manualmente. Por isso migrações são pequenas e revisadas pelo DBA.
  $MYSQL "$DB_NAME" < "$f"
  SQL "INSERT INTO schema_migrations (version) VALUES ('$v')"
done
echo "OK"
