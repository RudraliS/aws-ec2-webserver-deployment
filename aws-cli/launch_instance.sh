#!/usr/bin/env bash
# ==============================================================================
# Script Name: launch_instance.sh
# Description: Automated AWS CLI script to create a restricted Security Group,
#              generate/import Key Pair, and launch an Ubuntu EC2 instance
#              with Nginx pre-configured via user-data.
# ==============================================================================

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="t2.micro"
KEY_NAME="ec2-webserver-key"
SG_NAME="webserver-restricted-sg"

echo "=== AWS EC2 Automated Provisioning ==="
echo "Target Region: ${AWS_REGION}"

# 1. Detect user's current public IP for restricted SSH
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Detected Public IP: ${MY_IP}"

# 2. Query latest Ubuntu 22.04 LTS AMI ID
echo "Fetching latest Ubuntu 22.04 AMI ID..."
AMI_ID=$(aws ec2 describe-images \
    --region "${AWS_REGION}" \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
              "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)

echo "Selected AMI: ${AMI_ID}"

# 3. Create Key Pair if it doesn't already exist
if ! aws ec2 describe-key-pairs --key-names "${KEY_NAME}" --region "${AWS_REGION}" &>/dev/null; then
    echo "Creating Key Pair '${KEY_NAME}'..."
    aws ec2 create-key-pair \
        --key-name "${KEY_NAME}" \
        --region "${AWS_REGION}" \
        --query "KeyMaterial" \
        --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "Private key saved locally to: ${KEY_NAME}.pem"
else
    echo "Key pair '${KEY_NAME}' already exists in AWS."
fi

# 4. Create Security Group
VPC_ID=$(aws ec2 describe-vpcs --region "${AWS_REGION}" --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

if ! aws ec2 describe-security-groups --group-names "${SG_NAME}" --region "${AWS_REGION}" &>/dev/null; then
    echo "Creating Security Group '${SG_NAME}' in VPC ${VPC_ID}..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name "${SG_NAME}" \
        --description "Restricted SG for Web Server: Port 80 Open, Port 22 Restricted" \
        --vpc-id "${VPC_ID}" \
        --region "${AWS_REGION}" \
        --output text --query "GroupId")

    echo "Authorizing Inbound Rules:"
    # Inbound SSH (Port 22) RESTRICTED to current IP only
    echo "- Authorizing Port 22 (SSH) from ${MY_IP}/32 only..."
    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --protocol tcp \
        --port 22 \
        --cidr "${MY_IP}/32" \
        --region "${AWS_REGION}"

    # Inbound HTTP (Port 80) open to World
    echo "- Authorizing Port 80 (HTTP) from 0.0.0.0/0..."
    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "${AWS_REGION}"
else
    SG_ID=$(aws ec2 describe-security-groups --group-names "${SG_NAME}" --region "${AWS_REGION}" --query "SecurityGroups[0].GroupId" --output text)
    echo "Using existing Security Group: ${SG_ID}"
fi

# 5. Launch EC2 Instance with User Data
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA_FILE="${SCRIPT_DIR}/../scripts/user_data.sh"

echo "Launching EC2 Instance (${INSTANCE_TYPE})..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "${AMI_ID}" \
    --instance-type "${INSTANCE_TYPE}" \
    --key-name "${KEY_NAME}" \
    --security-group-ids "${SG_ID}" \
    --user-data "file://${USER_DATA_FILE}" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Nginx-Automated-Server}]' \
    --region "${AWS_REGION}" \
    --query "Instances[0].InstanceId" \
    --output text)

echo "Instance launched: ${INSTANCE_ID}"
echo "Waiting for instance to enter 'running' state..."
aws ec2 wait instance-running --instance-ids "${INSTANCE_ID}" --region "${AWS_REGION}"

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "${INSTANCE_ID}" \
    --region "${AWS_REGION}" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo "=== Deployment Successful ==="
echo "Instance ID: ${INSTANCE_ID}"
echo "Public IP:   ${PUBLIC_IP}"
echo "Access URL:  http://${PUBLIC_IP}"
echo "SSH Command: ssh -i ${KEY_NAME}.pem ubuntu@${PUBLIC_IP}"
