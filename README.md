# Automated Web Server Deployment on AWS EC2

[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20CloudWatch-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![OS](https://img.shields.io/badge/OS-Ubuntu%2022.04%20LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![Web Server](https://img.shields.io/badge/Server-Nginx-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![Automation](https://img.shields.io/badge/Automation-Bash%20Scripting-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

A production-ready infrastructure automation project demonstrating the automated provisioning and configuration of a hardened Nginx web server on an AWS EC2 Ubuntu instance with key-based SSH authentication, a restricted security group, and automated CloudWatch CPU monitoring alarms.

---

## Architecture Overview

```
                          +-------------------------------------------------+
                          |                   AWS Cloud                     |
                          |                                                 |
                          |   +------------------------------------------+  |
                          |   |        VPC / Public Subnet               |  |
                          |   |                                          |  |
  Internet (HTTP :80) ----+-->|  [Restricted Security Group]             |  |
                          |   |    ├── Port 80  (Inbound: 0.0.0.0/0)     |  |
  Admin (SSH :22) --------+-->|    └── Port 22  (Inbound: Admin IP/32)   |  |
  (Key-based Auth)        |   |                 │                        |  |
                          |   |                 ▼                        |  |
                          |   |      +---------------------+             |  |
                          |   |      |  Ubuntu 22.04 LTS   |             |  |
                          |   |      |  t2.micro Instance  |             |  |
                          |   |      |                     |             |  |
                          |   |      |  • Nginx Service    |             |  |
                          |   |      |  • UFW Firewall     |             |  |
                          |   |      |  • Hardened Config  |             |  |
                          |   |      +----------┬----------+             |  |
                          |   +-----------------│------------------------+  |
                          |                     ▼                           |
                          |          [Amazon CloudWatch]                    |
                          |          Metric: CPUUtilization                 |
                          |          Alarm: >= 80% (10 min)                 |
                          |          Action: SNS Notification               |
                          +-------------------------------------------------+
```

---

## Features

- **Automated Single-Run Installation**: Idempotent Bash script (`scripts/install_nginx.sh`) that updates system packages, installs Nginx, applies security headers, and launches a dynamic landing page.
- **Restricted Security Group**: Inbound SSH (Port 22) restricted strictly to your administrative IP address; HTTP (Port 80) and HTTPS (Port 443) open to web traffic.
- **Key-Based Authentication**: Secure ED25519 or RSA-2048 key-pair access with password authentication disabled by default.
- **EC2 User-Data Bootstrap**: Hands-off instance initialization script (`scripts/user_data.sh`) configured on launch.
- **Proactive CloudWatch Monitoring**: Automated metric alarm configuration (`scripts/setup_cloudwatch_alarm.sh`) alerting when CPU exceeds 80% for 10 continuous minutes.
- **UFW Firewall Hardening**: Host-level firewall enabled with rate-limited access rules and restricted port policies.

---

## Directory Structure

```
aws-ec2-webserver-deployment/
├── aws-cli/
│   └── launch_instance.sh         # Complete AWS CLI deployment automation script
├── scripts/
│   ├── install_nginx.sh           # One-run Nginx installer and configuration script
│   ├── setup_cloudwatch_alarm.sh  # CloudWatch CPU alarm configuration script
│   └── user_data.sh               # Cloud-init user data script for EC2
├── .gitignore                     # Ignores local keys, logs, and sensitive files
└── README.md                      # Detailed technical documentation
```

---

## Prerequisites

1. An active [AWS Account](https://aws.amazon.com/).
2. [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) installed and configured (`aws configure`).
3. An active SSH client (OpenSSH / PuTTY).

---

## Step-by-Step Deployment

### Method 1: Automated AWS CLI Deployment (Recommended)

Run the automated provisioning script directly:

```bash
chmod +x aws-cli/launch_instance.sh
./aws-cli/launch_instance.sh
```

This script automatically:
1. Detects your public IP and restricts Port 22 to `your-ip/32`.
2. Creates an AWS key pair (`ec2-webserver-key.pem`).
3. Creates a restricted Security Group (`webserver-restricted-sg`).
4. Launches an Ubuntu 22.04 LTS instance with `scripts/user_data.sh` attached.
5. Waits for the instance to become healthy and outputs the public IP.

---

### Method 2: Manual AWS Management Console Deployment

#### 1. Create a Key Pair
- Go to **EC2 Console** > **Network & Security** > **Key Pairs**.
- Click **Create key pair**, name it `ec2-webserver-key`, select **RSA** and `.pem`.
- Download the file and secure it:
  ```bash
  chmod 400 ec2-webserver-key.pem
  ```

#### 2. Create Restricted Security Group
- Go to **EC2 Console** > **Network & Security** > **Security Groups** > **Create security group**.
- **Inbound Rules**:
  - `Type`: **SSH**, `Port`: **22**, `Source`: **My IP** (Restricts access exclusively to you).
  - `Type`: **HTTP**, `Port`: **80**, `Source`: **Anywhere-IPv4** (`0.0.0.0/0`).
  - `Type`: **HTTPS**, `Port`: **443**, `Source`: **Anywhere-IPv4** (`0.0.0.0/0`).
- **Outbound Rules**: All traffic (`0.0.0.0/0`).

#### 3. Launch the Instance
- Click **Launch Instance**.
- **AMI**: Ubuntu Server 22.04 LTS (HVM, SSD Volume Type).
- **Instance Type**: `t2.micro` (Free tier eligible).
- **Key Pair**: Select `ec2-webserver-key`.
- **Network Settings**: Choose the security group created above.
- **Advanced Details > User Data**: Paste the contents of `scripts/user_data.sh`.
- Click **Launch Instance**.

#### 4. Connect and Run Nginx Setup Manually (Alternative)
If you prefer running the script manually over SSH:
```bash
ssh -i ec2-webserver-key.pem ubuntu@<INSTANCE_PUBLIC_IP>

# Clone or copy install_nginx.sh and execute
chmod +x scripts/install_nginx.sh
sudo ./scripts/install_nginx.sh
```

---

## CloudWatch Monitoring Setup

To set up an alert when CPU utilization reaches or exceeds 80%:

```bash
chmod +x scripts/setup_cloudwatch_alarm.sh
./scripts/setup_cloudwatch_alarm.sh <INSTANCE_ID> [AWS_REGION] [OPTIONAL_SNS_ARN]
```

### Alarm Specification:
- **Metric**: `AWS/EC2 -> CPUUtilization`
- **Statistic**: Average
- **Period**: 300 seconds (5 minutes)
- **Evaluation Periods**: 2 consecutive datapoints
- **Threshold**: `>= 80%`
- **State Transition**: `OK` -> `ALARM`

---

## Verification & Testing

1. **Verify Web Server in Browser**:
   Navigate to:
   ```
   http://<INSTANCE_PUBLIC_IP>
   ```
   You will see the operational landing page displaying the instance ID, Availability Zone, and server status.

2. **Verify Nginx Service Status via SSH**:
   ```bash
   sudo systemctl status nginx
   sudo ufw status verbose
   ```

3. **Verify CloudWatch Alarm**:
   ```bash
   aws cloudwatch describe-alarms --alarm-names "EC2-High-CPU-Utilization-<INSTANCE_ID>"
   ```

4. **Simulate CPU Load (Stress Test)**:
   ```bash
   # Install stress tool
   sudo apt-get install -y stress
   # Generate 100% CPU load for 12 minutes
   stress --cpu 2 --timeout 720s
   ```
   Check the CloudWatch console: the alarm will transition to the **In Alarm** state.

---

## Security Hardening Implemented

| Security Layer | Implementation |
| :--- | :--- |
| **Network** | Restricted Security Group limiting SSH to administrator's IP |
| **Authentication** | Asymmetric key-pair authentication; password authentication disabled |
| **Host Firewall** | UFW configured to drop unsolicited incoming connections |
| **Nginx Hardening** | `server_tokens off;` (hiding Nginx version) and XSS/Clickjacking headers |
| **Monitoring** | CloudWatch metrics tracking abnormal CPU spikes and security events |

---

## Cleanup / Teardown

To avoid incurring unexpected AWS charges:
```bash
# Terminate EC2 Instance
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# Delete Security Group
aws ec2 delete-security-group --group-id <SG_ID>

# Delete CloudWatch Alarm
aws cloudwatch delete-alarms --alarm-names "EC2-High-CPU-Utilization-<INSTANCE_ID>"
```
