#!/usr/bin/env bash
set -euo pipefail

DB_NAME="tsuki"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_FILE="$SCRIPT_DIR/init_tsuki_db.sql"
FORCE_RECREATE="false"

if [ "${1:-}" = "--force-recreate" ]; then
  FORCE_RECREATE="true"
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql not found. Please install PostgreSQL first."
  exit 1
fi

if [ ! -f "$SQL_FILE" ]; then
  echo "Error: SQL file not found: $SQL_FILE"
  exit 1
fi

echo "Checking database '$DB_NAME'..."
DB_EXISTS="$(psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | tr -d '[:space:]')"

if [ "$FORCE_RECREATE" = "true" ]; then
  if [ "$DB_EXISTS" = "1" ]; then
    echo "Force recreate enabled. Dropping database '$DB_NAME'..."
    psql -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE $DB_NAME"
  fi
  echo "Creating database '$DB_NAME'..."
  psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE $DB_NAME WITH ENCODING 'UTF8' TEMPLATE template0"
elif [ "$DB_EXISTS" = "1" ]; then
  echo "Database '$DB_NAME' already exists. Skip create."
else
  echo "Database '$DB_NAME' not found. Creating..."
  psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE $DB_NAME WITH ENCODING 'UTF8' TEMPLATE template0"
fi

echo "Applying schema from $SQL_FILE ..."
psql -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$SQL_FILE"

echo "Done. Database '$DB_NAME' is ready."
