# Nginx Proxy Manager Configuration for Remote Chatwoot

This guide explains how to configure Nginx Proxy Manager (NPM) on VPS 1 to proxy to Chatwoot on VPS 2.

## Prerequisites

- NPM installed and running on VPS 1
- Chatwoot deployed on VPS 2 using `docker-compose.production.yaml`
- Firewall configured on VPS 2 to allow NPM access
- Domain name pointing to NPM server (VPS 1)

## Step 1: Add Proxy Host in NPM

1. Log into your NPM admin panel (usually `http://npm-server-ip:81`)

2. Navigate to **Hosts** → **Proxy Hosts** → **Add Proxy Host**

3. Configure the **Details** tab:
   ```
   Domain Names: chatwoot.yourdomain.com
   Scheme: http
   Forward Hostname / IP: [CHATWOOT_VPS_IP]
   Forward Port: 3000
   
   ✓ Cache Assets
   ✓ Block Common Exploits
   ✓ Websockets Support (CRITICAL - Required for real-time features)
   ```

## Step 2: Configure SSL Certificate

1. Switch to the **SSL** tab

2. Select SSL Certificate:
   ```
   SSL Certificate: Request a new SSL Certificate
   ✓ Force SSL
   Email Address: admin@yourdomain.com
   ✓ I Agree to the Let's Encrypt Terms of Service
   ```

3. Click **Save** to generate the certificate

## Step 3: Add Custom Nginx Configuration

1. After saving, edit the proxy host again

2. Go to the **Advanced** tab

3. Add this custom Nginx configuration:

```nginx
# Required headers for Chatwoot
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

# Increase timeouts for long-running requests
proxy_read_timeout 300;
proxy_connect_timeout 300;
proxy_send_timeout 300;

# Increase buffer sizes
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 24 4k;
proxy_busy_buffers_size 8k;
proxy_max_temp_file_size 2048m;
proxy_temp_file_write_size 32k;

# WebSocket configuration for ActionCable
location /cable {
    proxy_pass http://[CHATWOOT_VPS_IP]:3000/cable;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    
    # Disable buffering for WebSocket
    proxy_buffering off;
}

# File upload size limit (100MB)
client_max_body_size 100M;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;

# Hide Nginx version
proxy_hide_header X-Powered-By;
proxy_hide_header Server;
```

**IMPORTANT**: Replace `[CHATWOOT_VPS_IP]` with your actual Chatwoot server IP address!

## Step 4: Test the Configuration

1. **Check proxy is working**:
   ```bash
   curl -I https://chatwoot.yourdomain.com
   ```
   Should return HTTP 200 or redirect to login

2. **Test WebSocket connection**:
   - Open browser developer console
   - Navigate to your Chatwoot instance
   - Look for WebSocket connections to `/cable`
   - Should show "Status: 101 Switching Protocols"

3. **Verify SSL certificate**:
   ```bash
   openssl s_client -connect chatwoot.yourdomain.com:443 -servername chatwoot.yourdomain.com
   ```

## Step 5: Configure Access Lists (Optional but Recommended)

For additional security, create an Access List:

1. Go to **Access Lists** → **Add Access List**

2. Configure:
   ```
   Name: Chatwoot Admin IPs
   
   Allow:
   - Your office IP
   - Your home IP
   - Team member IPs
   
   Deny:
   - Leave empty (implicit deny all others)
   ```

3. Apply to proxy host under **Access** tab

## Troubleshooting

### 502 Bad Gateway
- Verify Chatwoot VPS IP is correct
- Check firewall allows NPM server IP on port 3000
- Ensure Chatwoot is running: `docker ps` on VPS 2

### WebSocket Connection Failed
- Ensure "Websockets Support" is enabled in NPM
- Check browser console for specific errors
- Verify `/cable` location block in custom config

### SSL Certificate Issues
- Ensure domain DNS points to NPM server
- Check NPM can reach Let's Encrypt servers
- Try using DNS challenge if HTTP challenge fails

### Slow Performance
- Increase proxy timeouts in custom config
- Check network latency between VPSs
- Consider using a CDN for static assets

## Network Diagram

```
Internet Users
      ↓
[NPM on VPS 1]
  Port 80/443
      ↓
Private/Public Network
      ↓
[Chatwoot on VPS 2]
   Port 3000
   (Firewall: Only NPM IP allowed)
```

## Security Checklist

- [ ] Firewall on VPS 2 configured to allow only NPM IP
- [ ] SSL certificate active and auto-renewing
- [ ] WebSocket connections working
- [ ] Access lists configured (if needed)
- [ ] Regular NPM updates scheduled
- [ ] Backup of NPM configuration exists

## Monitoring

Consider setting up monitoring for:
- SSL certificate expiration
- Proxy host availability
- Response time from NPM to Chatwoot
- WebSocket connection stability

## Notes

- NPM to Chatwoot communication is over HTTP (port 3000)
- SSL termination happens at NPM level
- Ensure both VPSs have stable network connection
- Consider using private networking if available from your VPS provider