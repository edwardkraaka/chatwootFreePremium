#!/bin/bash

# Chatwoot Firewall Configuration Script
# Purpose: Secure Chatwoot VPS to only allow NPM access on port 3000

set -e

# IMPORTANT: Replace this with your NPM server's actual IP address
NPM_SERVER_IP="YOUR_NPM_SERVER_IP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Chatwoot VPS Firewall Configuration ===${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}" 
   exit 1
fi

# Check if NPM_SERVER_IP is configured
if [ "$NPM_SERVER_IP" == "YOUR_NPM_SERVER_IP" ]; then
    echo -e "${RED}ERROR: You must set the NPM_SERVER_IP variable first!${NC}"
    echo -e "${YELLOW}Edit this script and replace YOUR_NPM_SERVER_IP with your NPM server's actual IP${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuring firewall for NPM server at: $NPM_SERVER_IP${NC}"
echo ""

# Install UFW if not present
if ! command -v ufw &> /dev/null; then
    echo "Installing UFW firewall..."
    apt-get update
    apt-get install -y ufw
fi

# Reset UFW to defaults (optional - comment out if you have existing rules)
# echo "Resetting UFW to defaults..."
# ufw --force reset

# Default policies
echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (CRITICAL - don't lock yourself out!)
echo "Allowing SSH access..."
ufw allow 22/tcp comment 'SSH'

# Allow HTTP and HTTPS for Let's Encrypt (if running on this server)
# Uncomment if you need direct web access for any reason
# ufw allow 80/tcp comment 'HTTP'
# ufw allow 443/tcp comment 'HTTPS'

# Allow port 3000 ONLY from NPM server
echo "Allowing port 3000 access from NPM server ($NPM_SERVER_IP)..."
ufw allow from $NPM_SERVER_IP to any port 3000 comment 'Chatwoot from NPM'

# Optional: Allow access from a backup IP or monitoring service
# ufw allow from BACKUP_IP to any port 3000 comment 'Backup NPM'

# Explicitly deny all other access to port 3000
echo "Denying all other access to port 3000..."
ufw deny 3000 comment 'Block public access to Chatwoot'

# Optional: Allow private network access (adjust subnet as needed)
# This is useful if your VPSs are on the same private network
# ufw allow from 10.0.0.0/8 to any port 3000 comment 'Private network'
# ufw allow from 172.16.0.0/12 to any port 3000 comment 'Private network'
# ufw allow from 192.168.0.0/16 to any port 3000 comment 'Private network'

# Enable UFW
echo "Enabling firewall..."
ufw --force enable

# Show status
echo ""
echo -e "${GREEN}Firewall configuration complete!${NC}"
echo ""
echo "Current firewall status:"
ufw status verbose

echo ""
echo -e "${GREEN}=== Security Summary ===${NC}"
echo "✓ SSH (port 22): Open to all (for management)"
echo "✓ Chatwoot (port 3000): Open ONLY to NPM server ($NPM_SERVER_IP)"
echo "✓ PostgreSQL (port 5432): Blocked (internal only via Docker)"
echo "✓ Redis (port 6379): Blocked (internal only via Docker)"
echo ""
echo -e "${YELLOW}IMPORTANT NOTES:${NC}"
echo "1. Test SSH access before closing your current session"
echo "2. Verify NPM can still reach port 3000"
echo "3. To add another allowed IP: sudo ufw allow from NEW_IP to any port 3000"
echo "4. To check logs: sudo ufw status verbose"
echo "5. To disable firewall in emergency: sudo ufw disable"