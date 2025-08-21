# Docker Setup Guide for Chatwoot

## Quick Start (Fresh Installation)

1. Start all services:
```bash
docker compose up -d
```

2. Wait for initialization (check logs):
```bash
docker compose logs -f rails
```

3. Access Chatwoot at http://localhost:3000

## Database Backup & Restore

### The Proper Workflow

1. **First Time Setup**: Let Chatwoot initialize completely
   - Database schema is created automatically
   - Migrations run on first startup
   - Initial seed data is added (if no backup.sql exists)

2. **Restoring from Backup** (AFTER initialization):
   ```bash
   # Place your backup.sql in the project root
   cp /path/to/your/backup.sql ./backup.sql
   
   # After Chatwoot is running, restore the backup
   docker compose exec rails /app/docker/scripts/restore-backup.sh
   ```

3. **Creating a Backup**:
   ```bash
   docker compose exec postgres pg_dump -U postgres chatwoot_production > backup_$(date +%Y%m%d).sql
   ```

## Important Notes

### Why Separate Initialization and Restore?

The previous approach of dropping and recreating the database with backup.sql was flawed because:
- It prevented Chatwoot from initializing its schema properly
- It could miss new migrations from Chatwoot updates
- It caused the "relation does not exist" errors

The new approach:
1. Always lets Chatwoot initialize first (creates proper schema)
2. Restores data separately, preserving the schema
3. Ensures compatibility with Chatwoot updates

### Troubleshooting

If you see "relation 'installation_configs' does not exist":
1. The database wasn't initialized properly
2. Solution: Remove volumes and start fresh
   ```bash
   docker compose down
   docker volume rm chatwootfreepremium_postgres_data
   docker compose up -d
   ```

### Environment Variables

Key database variables in `.env`:
- `POSTGRES_HOST=postgres`
- `POSTGRES_DATABASE=chatwoot_production`
- `POSTGRES_USERNAME=postgres`
- `POSTGRES_PASSWORD=` (your password)

## Development Workflow

1. **Start services**: `docker compose up -d`
2. **Watch logs**: `docker compose logs -f rails`
3. **Run console**: `docker compose exec rails bundle exec rails console`
4. **Run migrations**: `docker compose exec rails bundle exec rails db:migrate`
5. **Stop services**: `docker compose down`

## Using External Database (Supabase)

For production, use the Supabase compose file:
```bash
docker compose -f docker-compose-supabase.yaml up -d
```

This connects to your external Supabase database instead of local Postgres.