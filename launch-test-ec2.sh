#!/bin/bash

# Script to launch EC2 instance for testing private API Gateway
# This creates the necessary IAM role and launches the instance

set -e
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== EC2 Instance Setup for Private API Testing ===${NC}\n"

# Set region
REGION="us-east-1"

# Get VPC and subnet from stack
echo -e "${YELLOW}Getting VPC configuration...${NC}"
VPC_ID=$(aws cloudformation describe-stacks \
  --region $REGION \
  --stack-name weather-api-private-dev \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
  --output text)

PRIVATE_SUBNET=$(aws cloudformation describe-stacks \
  --region $REGION \
  --stack-name weather-api-private-dev \
  --query "Stacks[0].Outputs[?OutputKey=='PrivateSubnetId'].OutputValue" \
  --output text)

echo -e "${GREEN}VPC ID:${NC} $VPC_ID"
echo -e "${GREEN}Private Subnet:${NC} $PRIVATE_SUBNET"
echo ""

# Create IAM role for EC2 with SSM access (if not exists)
ROLE_NAME="WeatherAPITestEC2Role"
echo -e "${YELLOW}Creating IAM role for EC2...${NC}"

# Check if role exists
if aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
  echo -e "${GREEN}Role $ROLE_NAME already exists${NC}"
else
  # Create role
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }' \
    --description "Role for EC2 instance to test private API Gateway"
  
  echo -e "${GREEN}Created role: $ROLE_NAME${NC}"
  
  # Attach SSM policy
  aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  
  echo -e "${GREEN}Attached SSM policy${NC}"
fi

# Create instance profile (if not exists)
PROFILE_NAME="WeatherAPITestEC2Profile"
echo -e "${YELLOW}Creating instance profile...${NC}"

if aws iam get-instance-profile --instance-profile-name $PROFILE_NAME 2>/dev/null; then
  echo -e "${GREEN}Instance profile $PROFILE_NAME already exists${NC}"
else
  aws iam create-instance-profile \
    --instance-profile-name $PROFILE_NAME
  
  # Wait for profile to be created
  sleep 5
  
  # Add role to instance profile
  aws iam add-role-to-instance-profile \
    --instance-profile-name $PROFILE_NAME \
    --role-name $ROLE_NAME
  
  echo -e "${GREEN}Created instance profile: $PROFILE_NAME${NC}"
  
  # Wait for IAM changes to propagate
  echo -e "${YELLOW}Waiting for IAM changes to propagate (10 seconds)...${NC}"
  sleep 10
fi
echo ""

# Create security group for EC2
SG_NAME="weather-api-test-sg"
echo -e "${YELLOW}Creating security group...${NC}"

# Check if security group exists
SG_ID=$(aws ec2 describe-security-groups \
  --region $REGION \
  --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "None")

if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
  echo -e "${GREEN}Security group already exists: $SG_ID${NC}"
else
  SG_ID=$(aws ec2 create-security-group \
    --region $REGION \
    --group-name $SG_NAME \
    --description "Security group for testing private API Gateway" \
    --vpc-id $VPC_ID \
    --query 'GroupId' \
    --output text)
  
  echo -e "${GREEN}Created security group: $SG_ID${NC}"
  
  echo -e "${GREEN}Created security group${NC}"
fi
echo ""

# Launch EC2 instance
echo -e "${YELLOW}Launching EC2 instance...${NC}"

INSTANCE_ID=$(aws ec2 run-instances \
  --region $REGION \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --subnet-id $PRIVATE_SUBNET \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=$PROFILE_NAME \
  --associate-public-ip-address \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=weather-api-test}]" \
  --user-data '#!/bin/bash
yum update -y
yum install -y curl python3 jq
' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo -e "${GREEN}✓ Instance launched: $INSTANCE_ID${NC}"
echo ""

# Wait for instance to be running
echo -e "${YELLOW}Waiting for instance to be running...${NC}"
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCE_ID
echo -e "${GREEN}✓ Instance is running${NC}"
echo ""

# Get instance details
PUBLIC_IP=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

PRIVATE_IP=$(aws ec2 describe-instances \
  --region $REGION \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Instance Details:${NC}"
echo -e "  Instance ID: ${INSTANCE_ID}"
echo -e "  Public IP: ${PUBLIC_IP}"
echo -e "  Private IP: ${PRIVATE_IP}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Wait for SSM to be ready
echo -e "${YELLOW}Waiting for SSM Agent to be online (this may take 2-3 minutes)...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  SSM_STATUS=$(aws ssm describe-instance-information \
    --region $REGION \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query "InstanceInformationList[0].PingStatus" \
    --output text 2>/dev/null || echo "None")
  
  if [ "$SSM_STATUS" == "Online" ]; then
    echo -e "${GREEN}✓ SSM Agent is online!${NC}"
    break
  fi
  
  echo -e "${YELLOW}  Status: $SSM_STATUS - waiting... ($((RETRY_COUNT+1))/$MAX_RETRIES)${NC}"
  sleep 10
  ((RETRY_COUNT++))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo -e "${RED}⚠ SSM Agent did not come online within expected time${NC}"
  echo -e "${YELLOW}You can still try to connect in a few minutes${NC}"
fi
echo ""

# Instructions
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}1. Connect to the instance via Session Manager:${NC}"
echo -e "   ${GREEN}aws ssm start-session --region $REGION --target $INSTANCE_ID${NC}"
echo ""
echo -e "${YELLOW}2. Once connected, run the test script:${NC}"
echo -e "   ${GREEN}curl -o test-api.sh https://raw.githubusercontent.com/.../test-from-ec2.sh${NC}"
echo -e "   ${GREEN}chmod +x test-api.sh && ./test-api.sh${NC}"
echo ""
echo -e "${YELLOW}3. Or test directly with curl:${NC}"
cat << 'TESTCMD'
   API_ID="609x52qn26"
   VPCE_ID="vpce-0df7e09a0bc49a117"
   REGION="us-east-1"
   
   VPCE_DNS=$(aws ec2 describe-vpc-endpoints \
     --vpc-endpoint-ids $VPCE_ID \
     --query "VpcEndpoints[0].DnsEntries[0].DnsName" \
     --output text)
   
   curl -X GET \
     "https://${VPCE_DNS}/dev/weather?q=33418" \
     -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com" \
     -H "accept: application/json"
TESTCMD
echo ""
echo -e "${YELLOW}4. To cleanup when done:${NC}"
echo -e "   ${GREEN}aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
