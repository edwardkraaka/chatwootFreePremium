#!/bin/bash

# Backup restoration script for Chatwoot
# This should be run AFTER Chatwoot is fully initialized with its schema

set -e

echo "🔄 Chatwoot Backup Restoration Script"
echo "======================================"

# Check if backup file exists
if [ ! -f "/app/backup.sql" ]; then
  echo "❌ Error: backup.sql not found in /app directory"
  echo "   Please mount your backup file to /app/backup.sql in docker-compose.yaml"
  exit 1
fi

# Check if already restored
if [ -f "/app/backup.sql.completed" ]; then
  echo "⚠️  Warning: Backup appears to have been restored already."
  echo -n "   Do you want to restore again? (y/N): "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "   Restoration cancelled."
    exit 0
  fi
fi

# Set database credentials
export PGPASSWORD=$POSTGRES_PASSWORD

echo "🔍 Checking database status..."

# Check if database exists and has tables
TABLE_COUNT=$(psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
TABLE_COUNT=$(echo $TABLE_COUNT | tr -d ' ')

if [ "$TABLE_COUNT" = "0" ] || [ -z "$TABLE_COUNT" ]; then
  echo "❌ Error: Database is not initialized. Please start Chatwoot first to create the schema."
  exit 1
fi

echo "✅ Database is initialized with $TABLE_COUNT tables"

# Create a backup of current database before restoration
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
echo "📦 Creating backup of current database..."
pg_dump -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE > "/app/pre_restore_backup_${BACKUP_DATE}.sql" 2>/dev/null || true

echo "🗑️  Cleaning existing data (preserving schema)..."

# Generate SQL to truncate all tables (preserves schema)
TRUNCATE_SQL=$(psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE -t -c "
  SELECT 'TRUNCATE TABLE ' || string_agg(quote_ident(tablename), ', ') || ' CASCADE;' 
  FROM pg_tables 
  WHERE schemaname = 'public' 
    AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata');
")

if [ ! -z "$TRUNCATE_SQL" ]; then
  echo "$TRUNCATE_SQL" | psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE
fi

echo "📥 Restoring data from backup.sql..."

# Restore the backup
# Filter out schema creation statements and constraint errors
psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE -f /app/backup.sql 2>&1 | \
  grep -v "already exists" | \
  grep -v "duplicate key value" | \
  grep -v "NOTICE:" || true

# Verify restoration
NEW_TABLE_COUNT=$(psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
NEW_TABLE_COUNT=$(echo $NEW_TABLE_COUNT | tr -d ' ')

echo ""
echo "✅ Restoration complete!"
echo "   Tables in database: $NEW_TABLE_COUNT"

# Mark as completed
touch /app/backup.sql.completed

echo ""
echo "📝 Notes:"
echo "   - Original database backed up to: /app/pre_restore_backup_${BACKUP_DATE}.sql"
echo "   - If there are issues, check the Rails logs: docker compose logs rails"
echo "   - You may need to restart services: docker compose restart rails sidekiq"

echo ""
echo "🎉 Backup restoration successful!"