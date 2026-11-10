#!/usr/bin/env bash
# Copia as sobreposições da SP Capital para dependências de terceiros já baixadas.
# Uso: infra/scripts/install-overlays.sh /caminho/do/server/resources/[ox]/ox_inventory
set -euo pipefail
TARGET="${1:?informe o caminho do ox_inventory}"
SRC="$(cd "$(dirname "$0")/../../game/overlays/ox_inventory" && pwd)"
[ -f "$TARGET/fxmanifest.lua" ] || { echo "ox_inventory não encontrado em $TARGET"; exit 1; }

if [ ! -f "$TARGET/data/items_upstream.lua" ]; then
  mv "$TARGET/data/items.lua" "$TARGET/data/items_upstream.lua"
  echo "items.lua original preservado como items_upstream.lua"
fi
cp -r "$SRC/." "$TARGET/"
echo "Sobreposições instaladas. Defina no server.cfg: setr inventory:framework \"spc\""
