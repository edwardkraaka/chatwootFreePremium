#!/bin/bash

# Script to refresh asset URLs after changing FRONTEND_URL
# Usage: docker compose exec rails /app/docker/scripts/refresh-asset-urls.sh

set -e

echo "🔄 Refreshing asset URLs for new domain..."
echo "================================================"

# Get current FRONTEND_URL
if [ -z "$FRONTEND_URL" ]; then
    echo "❌ Error: FRONTEND_URL environment variable is not set"
    exit 1
fi

echo "📍 Current FRONTEND_URL: $FRONTEND_URL"
echo ""

# Clear Rails cache
echo "1️⃣  Clearing Rails cache..."
bundle exec rails tmp:cache:clear
echo "   ✅ Rails cache cleared"
echo ""

# Clear Redis cache (if Redis is available)
echo "2️⃣  Clearing Redis cache..."
if bundle exec rails runner "Redis.new.flushdb" 2>/dev/null; then
    echo "   ✅ Redis cache cleared"
else
    echo "   ⚠️  Redis not available or already empty"
fi
echo ""

# Clear compiled assets cache
echo "3️⃣  Clearing compiled assets..."
rm -rf /app/public/packs
rm -rf /app/public/vite
rm -rf /app/tmp/cache/assets
echo "   ✅ Asset cache cleared"
echo ""

# Touch tmp/restart.txt to trigger app reload (if using Passenger)
echo "4️⃣  Triggering application reload..."
touch /app/tmp/restart.txt 2>/dev/null || true
echo "   ✅ Application reload triggered"
echo ""

# Run a Rails command to ensure Active Storage uses new URL
echo "5️⃣  Updating Active Storage configuration..."
bundle exec rails runner "
  Rails.application.routes.default_url_options[:host] = ENV['FRONTEND_URL']
  ActiveStorage::Current.url_options = { host: ENV['FRONTEND_URL'] }
  puts '   ✅ Active Storage URL configuration updated'
"
echo ""

# Clear Sidekiq cache/jobs if needed
echo "6️⃣  Checking Sidekiq queues..."
bundle exec rails runner "
  require 'sidekiq/api'
  
  # Clear retry set
  rs = Sidekiq::RetrySet.new
  if rs.size > 0
    puts \"   ℹ️  Found #{rs.size} jobs in retry queue\"
  end
  
  # Clear scheduled jobs
  ss = Sidekiq::ScheduledSet.new
  if ss.size > 0
    puts \"   ℹ️  Found #{ss.size} scheduled jobs\"
  end
  
  puts '   ✅ Sidekiq queues checked'
" 2>/dev/null || echo "   ⚠️  Sidekiq check skipped"
echo ""

echo "================================================"
echo "✨ Asset URL refresh complete!"
echo ""
echo "📝 Notes:"
echo "   - New uploads will use: $FRONTEND_URL"
echo "   - Existing attachments will now resolve to the new domain"
echo "   - You may need to refresh your browser cache"
echo ""
echo "💡 If you still see old URLs:"
echo "   1. Clear your browser cache"
echo "   2. Restart Sidekiq: docker compose restart sidekiq"
echo "   3. Full restart: docker compose down && docker compose up -d"
echo "================================================"