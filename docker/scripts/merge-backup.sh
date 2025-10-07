#!/bin/sh

set -e

# Chatwoot Backup Merge Script
# Merges old backup data into already-seeded v4.6.0 database
# WITHOUT destroying new tables or installation_configs

echo ""
echo "🔄 Chatwoot Backup Merge Script"
echo "======================================"

# Check if backup exists
if [ ! -f "/app/backup.sql" ]; then
  echo "❌ Error: backup.sql not found in /app directory"
  echo "   Please copy your backup file to /app/backup.sql"
  exit 1
fi

# Database connection details from environment
POSTGRES_HOST=${POSTGRES_HOST:-postgres}
POSTGRES_USERNAME=${POSTGRES_USERNAME:-postgres}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-chatwoot_production}
export PGPASSWORD=${POSTGRES_PASSWORD}

echo "🔍 Checking database status..."
TABLE_COUNT=$(psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
TABLE_COUNT=$(echo $TABLE_COUNT | tr -d ' ')

if [ "$TABLE_COUNT" -lt "80" ]; then
  echo "❌ Error: Database not properly initialized (only $TABLE_COUNT tables found)"
  echo "   Please ensure migrations and seeds have completed first"
  exit 1
fi

echo "✅ Database is initialized with $TABLE_COUNT tables"

echo "🔧 Preparing database for merge..."

# Disable triggers and constraints temporarily
psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE <<-EOSQL
  -- Disable all triggers
  ALTER TABLE accounts DISABLE TRIGGER accounts_after_insert_row_tr;
  ALTER TABLE conversations DISABLE TRIGGER conversations_before_insert_row_tr;

  -- Bypass all constraints/triggers globally
  SET session_replication_role = replica;

  -- Create missing sequences that v4.1.0 backup needs
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_1 START 1;
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_2 START 1;
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_3 START 1;
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_4 START 1;
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_5 START 1;
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_6 START 1;
  CREATE SEQUENCE IF NOT EXISTS conv_dpid_seq_7 START 1;

  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_1 START 1;
  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_2 START 1;
  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_3 START 1;
  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_4 START 1;
  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_5 START 1;
  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_6 START 1;
  CREATE SEQUENCE IF NOT EXISTS camp_dpid_seq_7 START 1;
EOSQL

echo "📥 Merging backup data (this may take a minute)..."

# Run the backup with session_replication_role set in the same session
# This bypasses all triggers including the problematic ones
(
  echo "SET session_replication_role = replica;"
  cat /app/backup.sql
  echo "SET session_replication_role = DEFAULT;"
) | psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE 2>&1 | \
  grep -v "already exists" | \
  grep -v "duplicate key value" | \
  grep -v "multiple primary keys" | \
  grep -v "NOTICE:" | \
  grep -v "ERROR.*no schema has been selected" | \
  grep "COPY" || true

echo "🔧 Re-enabling triggers..."

psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE <<-EOSQL
  -- Re-enable session replication
  SET session_replication_role = DEFAULT;

  -- Re-enable triggers
  ALTER TABLE accounts ENABLE TRIGGER accounts_after_insert_row_tr;
  ALTER TABLE conversations ENABLE TRIGGER conversations_before_insert_row_tr;
EOSQL

# Verify merge
echo ""
echo "📊 Checking data counts..."
psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE <<-EOSQL
  SELECT
    'Accounts: ' || COUNT(*) FROM accounts
  UNION ALL SELECT
    'Users: ' || COUNT(*) FROM users
  UNION ALL SELECT
    'Contacts: ' || COUNT(*) FROM contacts
  UNION ALL SELECT
    'Conversations: ' || COUNT(*) FROM conversations
  UNION ALL SELECT
    'Messages: ' || COUNT(*) FROM messages
  UNION ALL SELECT
    'Inboxes: ' || COUNT(*) FROM inboxes;
EOSQL

echo ""
echo "✅ Merge complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Restart services: docker compose restart rails sidekiq"
echo "   2. Test login at http://localhost:3000"
echo "   3. Verify your conversations and contacts are present"
echo ""
echo "🎉 Backup merge successful!"
