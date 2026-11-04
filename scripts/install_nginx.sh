#!/usr/bin/env bash
# ==============================================================================
# Script Name: install_nginx.sh
# Description: Automated one-run installation, hardening, and configuration
#              of Nginx on Ubuntu EC2 instances.
# Author: DevOps Automation
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Color Output & Logging
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo privileges."
   exit 1
fi

log_info "Starting automated Nginx installation and configuration..."

# ------------------------------------------------------------------------------
# 1. Update Package Repositories and System Packages
# ------------------------------------------------------------------------------
log_info "Updating apt package repository..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# ------------------------------------------------------------------------------
# 2. Install Nginx and Supporting Utilities
# ------------------------------------------------------------------------------
log_info "Installing Nginx, curl, and UFW..."
apt-get install -y nginx curl ufw

# ------------------------------------------------------------------------------
# 3. Configure Firewall (UFW)
# ------------------------------------------------------------------------------
log_info "Configuring UFW firewall rules..."
# Ensure OpenSSH remains allowed so we don't lock ourselves out
ufw allow OpenSSH || true
ufw allow 'Nginx Full' || true

if ! ufw status | grep -q "Status: active"; then
    log_info "Enabling UFW..."
    # Enable without prompt
    echo "y" | ufw enable
fi
log_success "Firewall configured: SSH (Port 22), HTTP (Port 80), and HTTPS (Port 443) allowed."

# ------------------------------------------------------------------------------
# 4. Deploy Custom Landing Page
# ------------------------------------------------------------------------------
log_info "Deploying custom web landing page..."
WEB_ROOT="/var/www/html"
mkdir -p "${WEB_ROOT}"

# Fetch EC2 Instance Metadata (IMDSv2) if available, fallback gracefully
IMDS_TOKEN=$(curl -s -S -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
if [[ -n "$IMDS_TOKEN" ]]; then
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "EC2-Unknown")
    AVAIL_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "Unknown-AZ")
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "127.0.0.1")
else
    INSTANCE_ID=$(hostname)
    AVAIL_ZONE="Local/On-Premise"
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi

cat <<EOF > "${WEB_ROOT}/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Server Active - AWS EC2</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: #f8fafc;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: rgba(30, 41, 59, 0.85);
            border: 1px solid #334155;
            backdrop-filter: blur(12px);
            border-radius: 16px;
            max-width: 650px;
            width: 100%;
            padding: 40px;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.4);
        }
        .badge {
            display: inline-block;
            background-color: #10b981;
            color: #ffffff;
            font-size: 0.85rem;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 9999px;
            margin-bottom: 16px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        h1 {
            font-size: 2rem;
            font-weight: 700;
            margin-bottom: 12px;
            color: #ffffff;
        }
        p.subtitle {
            color: #94a3b8;
            font-size: 1.05rem;
            margin-bottom: 24px;
            line-height: 1.5;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin-bottom: 24px;
        }
        .card {
            background: #0f172a;
            border: 1px solid #334155;
            padding: 16px;
            border-radius: 10px;
        }
        .card .label {
            font-size: 0.75rem;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 4px;
        }
        .card .value {
            font-size: 1rem;
            font-weight: 600;
            color: #38bdf8;
            word-break: break-all;
        }
        footer {
            border-top: 1px solid #334155;
            padding-top: 16px;
            font-size: 0.85rem;
            color: #64748b;
            display: flex;
            justify-content: space-between;
        }
    </style>
</head>
<body>
    <div class="container">
        <span class="badge">Operational</span>
        <h1>Automated Nginx Deployment</h1>
        <p class="subtitle">This Ubuntu EC2 web server was provisioned and configured completely automatically via Bash scripting and AWS Cloud automation.</p>
        
        <div class="grid">
            <div class="card">
                <div class="label">Instance ID</div>
                <div class="value">${INSTANCE_ID}</div>
            </div>
            <div class="card">
                <div class="label">Availability Zone</div>
                <div class="value">${AVAIL_ZONE}</div>
            </div>
            <div class="card">
                <div class="label">Server Public IP</div>
                <div class="value">${PUBLIC_IP}</div>
            </div>
            <div class="card">
                <div class="label">Web Engine</div>
                <div class="value">Nginx $(nginx -v 2>&1 | awk -F'/' '{print $2}')</div>
            </div>
        </div>

        <footer>
            <span>CloudWatch Monitoring: Active</span>
            <span>OS: Ubuntu Linux</span>
        </footer>
    </div>
</body>
</html>
EOF

chmod 644 "${WEB_ROOT}/index.html"
chown -R www-data:www-data "${WEB_ROOT}"

# ------------------------------------------------------------------------------
# 5. Security & Performance Hardening for Nginx
# ------------------------------------------------------------------------------
log_info "Configuring Nginx security parameters (hiding version, setting timeouts)..."

cat <<'EOF' > /etc/nginx/conf.d/security.conf
# Security & Performance Tuning
server_tokens off;
client_body_buffer_size 10K;
client_header_buffer_size 1k;
client_max_body_size 8m;
large_client_header_buffers 2 1k;
client_body_timeout 12;
client_header_timeout 12;
keepalive_timeout 15;
send_timeout 10;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
EOF

# ------------------------------------------------------------------------------
# 6. Verify Nginx Configuration & Restart Service
# ------------------------------------------------------------------------------
log_info "Testing Nginx configuration syntax..."
nginx -t

log_info "Enabling and restarting Nginx service..."
systemctl enable nginx
systemctl restart nginx

# ------------------------------------------------------------------------------
# 7. Verification Test
# ------------------------------------------------------------------------------
log_info "Verifying local HTTP response..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" http://localhost)

if [[ "$HTTP_STATUS" -eq 200 ]]; then
    log_success "Nginx is healthy and responding with HTTP status 200 OK!"
else
    log_warning "Nginx returned HTTP status $HTTP_STATUS. Please inspect /var/log/nginx/error.log"
fi

log_success "Automated deployment completed successfully!"
