#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

# Database initialization
export PGPASSWORD=$POSTGRES_PASSWORD

# Ensure database exists
if ! psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -lqt | cut -d \| -f 1 | grep -qw $POSTGRES_DATABASE; then
  echo "🆕 Creating database $POSTGRES_DATABASE..."
  psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -c "CREATE DATABASE $POSTGRES_DATABASE;"
fi

# Check if database is initialized (has tables)
TABLE_COUNT=$(psql -h $POSTGRES_HOST -U $POSTGRES_USERNAME -d $POSTGRES_DATABASE -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")
TABLE_COUNT=$(echo $TABLE_COUNT | tr -d ' ')

# If database is empty, run migrations to initialize Chatwoot schema
if [ "$TABLE_COUNT" = "0" ] || [ -z "$TABLE_COUNT" ]; then
  echo "📦 Initializing Chatwoot database schema..."
  bundle exec rails db:migrate
  
  # Check if we should seed the database
  if [ -f "/app/backup.sql" ]; then
    echo "ℹ️  Backup file detected, skipping seed data"
  else
    echo "🌱 Seeding initial data..."
    bundle exec rails db:seed
  fi
  
  echo "✅ Database schema initialized"
else
  echo "✅ Database already initialized with $TABLE_COUNT tables"
  
  # Check if migrations are pending
  if bundle exec rails db:migrate:status | grep -q "down"; then
    echo "🔄 Running pending migrations..."
    bundle exec rails db:migrate
  fi
fi

# NOTE: Backup restoration should be done separately after Chatwoot is fully initialized
# To restore a backup, use: docker compose exec rails /app/docker/scripts/restore-backup.sh

#install missing gems for local dev as we are using base image compiled for production
bundle install

BUNDLE="bundle check"

until $BUNDLE
do
  sleep 2;
done

# Execute the main process of the container
exec "$@"
