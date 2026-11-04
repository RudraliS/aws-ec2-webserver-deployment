#!/usr/bin/env bash
# ==============================================================================
# Script Name: setup_cloudwatch_alarm.sh
# Description: Provisions an AWS CloudWatch Alarm for High CPU Utilization
#              (triggers when average CPU exceeds 80% for 2 consecutive periods)
# Usage: ./setup_cloudwatch_alarm.sh <INSTANCE_ID> [AWS_REGION] [SNS_TOPIC_ARN]
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check dependencies
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is required but not installed. Please install 'awscli'."
    exit 1
fi

INSTANCE_ID="${1:-}"
AWS_REGION="${2:-us-east-1}"
SNS_TOPIC_ARN="${3:-}"

if [[ -z "$INSTANCE_ID" ]]; then
    # Attempt auto-detection if running inside EC2
    log_info "Instance ID not provided. Checking local EC2 metadata..."
    IMDS_TOKEN=$(curl -s -S -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
    if [[ -n "$IMDS_TOKEN" ]]; then
        INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || true)
    fi
fi

if [[ -z "$INSTANCE_ID" ]]; then
    log_error "Usage: $0 <INSTANCE_ID> [AWS_REGION] [SNS_TOPIC_ARN]"
    exit 1
fi

ALARM_NAME="EC2-High-CPU-Utilization-${INSTANCE_ID}"
METRIC_NAME="CPUUtilization"
NAMESPACE="AWS/EC2"
STATISTIC="Average"
PERIOD=300         # 5 minutes
EVAL_PERIODS=2      # 2 consecutive checks (total 10 minutes)
THRESHOLD=80        # 80% CPU usage
COMPARISON="GreaterThanOrEqualToThreshold"

log_info "Configuring CloudWatch Alarm for EC2 instance: ${INSTANCE_ID}"
log_info "Region: ${AWS_REGION} | Threshold: >= ${THRESHOLD}% over ${EVAL_PERIODS}x${PERIOD}s periods"

ALARM_ARGS=(
    --alarm-name "${ALARM_NAME}"
    --alarm-description "Triggers when EC2 instance CPU exceeds 80% for 10 minutes"
    --metric-name "${METRIC_NAME}"
    --namespace "${NAMESPACE}"
    --statistic "${STATISTIC}"
    --period "${PERIOD}"
    --evaluation-periods "${EVAL_PERIODS}"
    --threshold "${THRESHOLD}"
    --comparison-operator "${COMPARISON}"
    --dimensions "Name=InstanceId,Value=${INSTANCE_ID}"
    --region "${AWS_REGION}"
)

if [[ -n "$SNS_TOPIC_ARN" ]]; then
    log_info "Attaching SNS notification target: ${SNS_TOPIC_ARN}"
    ALARM_ARGS+=(--alarm-actions "${SNS_TOPIC_ARN}")
fi

# Create/Update CloudWatch Alarm
aws cloudwatch put-metric-alarm "${ALARM_ARGS[@]}"

log_success "CloudWatch alarm '${ALARM_NAME}' created successfully."

# Verification check
log_info "Verifying alarm status..."
aws cloudwatch describe-alarms \
    --alarm-names "${ALARM_NAME}" \
    --region "${AWS_REGION}" \
    --query "MetricAlarms[*].[AlarmName,StateValue,Threshold,EvaluationPeriods]" \
    --output table

log_success "Alarm configured and actively monitoring ${INSTANCE_ID}."
