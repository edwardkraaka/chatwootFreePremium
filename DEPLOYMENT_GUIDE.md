# Chatwoot Production Deployment Guide

Complete step-by-step guide for deploying Chatwoot with NPM on a separate VPS.

## Pre-Deployment Checklist

- [ ] You have root/sudo access to Chatwoot VPS (VPS 2)
- [ ] You have admin access to NPM (VPS 1)
- [ ] You know the IP address of your NPM server
- [ ] Docker and Docker Compose are installed on Chatwoot VPS
- [ ] You have a domain name pointing to NPM server
- [ ] Backup of any existing Chatwoot data is complete

## Phase 1: Prepare Chatwoot VPS

### Step 1: Upload Files to Chatwoot VPS

Transfer these files to your Chatwoot VPS:
```bash
# From your local machine
scp -r chatwootFreePremium/ user@chatwoot-vps-ip:/home/user/
```

### Step 2: Configure Environment

1. SSH into your Chatwoot VPS:
```bash
ssh user@chatwoot-vps-ip
cd chatwootFreePremium
```

2. Edit the `.env` file:
```bash
nano .env
```

Update these critical values:
- `FRONTEND_URL`: Set to your actual domain (e.g., https://chatwoot.yourdomain.com)
- `MAILER_SENDER_EMAIL`: Your notification email
- SMTP settings if you have email configured

3. Verify backup file exists:
```bash
ls -la backup.sql
# Should show your database backup file
```

### Step 3: Configure Firewall

1. Edit the firewall script with NPM server IP:
```bash
nano setup_firewall.sh
# Replace YOUR_NPM_SERVER_IP with actual NPM server IP
```

2. Run the firewall script:
```bash
sudo ./setup_firewall.sh
```

3. Verify firewall rules:
```bash
sudo ufw status verbose
```

## Phase 2: Deploy Chatwoot

### Step 1: Stop Any Existing Containers

```bash
# If you have existing Chatwoot running
docker compose down

# Clean up old volumes if doing fresh install (WARNING: Data loss!)
# docker volume prune
```

### Step 2: Deploy Production Configuration

```bash
# Start Chatwoot with production configuration
docker compose up -d

# Monitor the logs (especially database restoration)
docker compose logs -f
```

Wait for these messages:
- "📦 Found backup.sql - starting restore process..."
- "✅ Database restored successfully!"
- "Listening on http://0.0.0.0:3000"

Press `Ctrl+C` to exit logs (containers keep running).

### Step 3: Verify Services

```bash
# Check all containers are running
docker compose ps

# Should show:
# rails     - Up (healthy)
# sidekiq   - Up (healthy)
# postgres  - Up (healthy)
# redis     - Up (healthy)
```

### Step 4: Test Local Access

```bash
# Test Rails is responding
curl -I http://localhost:3000/api/v1/health_check

# Should return HTTP 200 OK
```

## Phase 3: Configure NPM (on VPS 1)

Follow the instructions in `NPM_REMOTE_SETUP.md` to:
1. Add proxy host for your domain
2. Configure SSL certificate
3. Add custom Nginx configuration
4. Enable WebSocket support

## Phase 4: Verification

### From Your Browser

1. **Access Chatwoot**:
   - Navigate to https://chatwoot.yourdomain.com
   - Should redirect to login page with SSL lock icon

2. **Test Login**:
   - Log in with your existing credentials
   - Verify you can access the dashboard

3. **Check WebSocket**:
   - Open browser DevTools (F12)
   - Go to Network tab
   - Look for `cable` connection
   - Status should be "101 Switching Protocols"

4. **Verify Premium Features**:
   - Check Captain AI is accessible
   - Verify audit logs are available
   - Confirm SLA features work

### From Chatwoot VPS

```bash
# Check logs for errors
docker compose logs --tail=50

# Monitor real-time logs
docker compose logs -f

# Check disk usage
df -h

# Check memory usage
free -h

# Verify ports (only 3000 should be open externally)
sudo netstat -tlnp | grep LISTEN
```

### Security Verification

```bash
# Test PostgreSQL is NOT accessible externally
nc -zv chatwoot-vps-ip 5432
# Should fail/timeout

# Test Redis is NOT accessible externally
nc -zv chatwoot-vps-ip 6379
# Should fail/timeout

# Test Rails IS accessible (only from NPM IP)
nc -zv chatwoot-vps-ip 3000
# Should succeed only from NPM server
```

## Phase 5: Post-Deployment

### 1. Remove Backup File (Optional)

After confirming everything works:
```bash
# The backup has been restored, safe to remove
rm backup.sql
# Or keep it as backup-completed.sql
mv backup.sql backup-completed.sql
```

### 2. Set Up Monitoring

Consider setting up:
- Uptime monitoring for your domain
- Docker container health monitoring
- Disk space alerts
- SSL certificate expiration alerts

### 3. Configure Backups

Set up automated backups:
```bash
# Create backup script
cat > backup_chatwoot.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec chatwootfreepremium-postgres-1 pg_dump -U postgres chatwoot_production > backup_$DATE.sql
# Optional: Upload to cloud storage
# aws s3 cp backup_$DATE.sql s3://your-bucket/chatwoot-backups/
EOF

chmod +x backup_chatwoot.sh

# Add to crontab for daily backups
crontab -e
# Add: 0 2 * * * /home/user/chatwootFreePremium/backup_chatwoot.sh
```

### 4. Update Documentation

Document for your team:
- Chatwoot VPS IP: ___________
- NPM VPS IP: ___________
- Domain: ___________
- Admin email: ___________
- Backup location: ___________

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose -f docker-compose.production.yaml logs rails

# Check disk space
df -h

# Check permissions
ls -la
```

### Database Issues

```bash
# Access PostgreSQL
docker exec -it chatwootfreepremium-postgres-1 psql -U postgres -d chatwoot_production

# Check tables
\dt

# Exit
\q
```

### 502 Bad Gateway in NPM

1. Verify Chatwoot is running: `docker ps`
2. Check firewall allows NPM IP: `sudo ufw status`
3. Test connectivity from NPM server: `curl http://chatwoot-vps-ip:3000`

### High Memory Usage

```bash
# Restart services
docker compose -f docker-compose.production.yaml restart

# Or restart individual service
docker compose -f docker-compose.production.yaml restart sidekiq
```

## Rollback Procedure

If something goes wrong:

```bash
# Stop production deployment
docker compose down

# Restore original configuration (if you have it)
docker compose -f docker-compose.original.yaml up -d

# Disable firewall restrictions
sudo ufw disable
```

## Maintenance Commands

```bash
# View logs
docker compose logs -f [service_name]

# Restart all services
docker compose restart

# Stop all services
docker compose stop

# Start all services
docker compose start

# Rebuild and restart
docker compose up -d --build

# Access Rails console
docker compose exec rails bundle exec rails console

# Run migrations manually
docker compose exec rails bundle exec rails db:migrate
```

## Success Indicators

✅ All Docker containers show "healthy" status
✅ Website accessible via HTTPS with valid certificate
✅ Can log in with existing credentials
✅ WebSocket connections working (real-time updates)
✅ Database and Redis NOT accessible from internet
✅ Port 3000 only accessible from NPM server
✅ Premium features functioning correctly
✅ Emails sending successfully (if configured)

## Support

If you encounter issues:
1. Check logs: `docker compose logs`
2. Verify firewall: `sudo ufw status verbose`
3. Test connectivity between VPSs
4. Ensure DNS is properly configured
5. Check NPM error logs on VPS 1

Remember to keep your system updated and monitor for security updates!