#!/bin/bash
# ==============================================================================
# EC2 User Data Bootstrap Script
# Automatically executed as root on instance launch
# ==============================================================================

set -euxo pipefail

# Output execution logs for troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting EC2 User Data initialization..."

# Update and install Nginx
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx curl ufw

# Security Group / Local Firewall settings
ufw allow OpenSSH
ufw allow 'Nginx Full'
echo "y" | ufw enable

# Retrieve instance details via IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

# Create Web landing page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>AWS EC2 Nginx Server</title>
    <style>
        body { font-family: sans-serif; background: #0f172a; color: #fff; text-align: center; padding-top: 50px; }
        .box { background: #1e293b; padding: 30px; display: inline-block; border-radius: 12px; border: 1px solid #334155; }
        h1 { color: #38bdf8; }
        p { color: #94a3b8; margin: 10px 0; }
        .badge { background: #10b981; color: white; padding: 5px 10px; border-radius: 5px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="box">
        <span class="badge">Running</span>
        <h1>Automated Nginx Deployment</h1>
        <p><strong>Instance ID:</strong> ${INSTANCE_ID}</p>
        <p><strong>Availability Zone:</strong> ${AZ}</p>
        <p><strong>Public IP:</strong> ${PUBLIC_IP}</p>
        <p>Deployed via User-Data &amp; Bash automation</p>
    </div>
</body>
</html>
EOF

# Ensure service is enabled & running
systemctl enable nginx
systemctl restart nginx

echo "EC2 bootstrap complete!"
