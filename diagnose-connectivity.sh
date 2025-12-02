#!/bin/bash

# Diagnostic script to run on EC2 instance
# Tests connectivity to VPC endpoint and API Gateway

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== VPC Endpoint Connectivity Diagnostics ==="
echo ""

# Configuration
VPCE_ID="vpce-0df7e09a0bc49a117"
API_ID="609x52qn26"
REGION="us-east-1"
VPCE_IP="10.0.1.23"

# Test 1: Basic network connectivity
echo -e "${YELLOW}Test 1: Ping VPC endpoint IP${NC}"
if ping -c 2 -W 2 $VPCE_IP > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Can ping VPC endpoint${NC}"
else
  echo -e "${RED}✗ Cannot ping VPC endpoint (ICMP may be blocked, this is normal)${NC}"
fi
echo ""

# Test 2: DNS resolution
echo -e "${YELLOW}Test 2: DNS Resolution${NC}"
VPCE_DNS=$(aws ec2 describe-vpc-endpoints \
  --region $REGION \
  --vpc-endpoint-ids $VPCE_ID \
  --query "VpcEndpoints[0].DnsEntries[0].DnsName" \
  --output text)

echo "VPC Endpoint DNS: $VPCE_DNS"

if nslookup "$VPCE_DNS" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ DNS resolution works${NC}"
  RESOLVED_IP=$(nslookup "$VPCE_DNS" | grep -A1 "Name:" | grep "Address:" | awk '{print $2}')
  echo "Resolves to: $RESOLVED_IP"
else
  echo -e "${RED}✗ DNS resolution failed${NC}"
fi
echo ""

# Test 3: Check VPC DNS settings
echo -e "${YELLOW}Test 3: VPC DNS Settings${NC}"
VPC_ID=$(aws ec2 describe-subnets --region $REGION --subnet-ids $(ec2-metadata --subnet-id | cut -d' ' -f2) --query "Subnets[0].VpcId" --output text 2>/dev/null || echo "unknown")
if [ "$VPC_ID" != "unknown" ]; then
  DNS_SUPPORT=$(aws ec2 describe-vpc-attribute --region $REGION --vpc-id $VPC_ID --attribute enableDnsSupport --query "EnableDnsSupport.Value" --output text)
  DNS_HOSTNAMES=$(aws ec2 describe-vpc-attribute --region $REGION --vpc-id $VPC_ID --attribute enableDnsHostnames --query "EnableDnsHostnames.Value" --output text)
  echo "DNS Support: $DNS_SUPPORT"
  echo "DNS Hostnames: $DNS_HOSTNAMES"
  
  if [ "$DNS_SUPPORT" == "true" ] && [ "$DNS_HOSTNAMES" == "true" ]; then
    echo -e "${GREEN}✓ VPC DNS configured correctly${NC}"
  else
    echo -e "${RED}✗ VPC DNS not properly configured${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Could not check VPC DNS settings${NC}"
fi
echo ""

# Test 4: TCP connection to VPC endpoint
echo -e "${YELLOW}Test 4: TCP Connection to VPC endpoint (port 443)${NC}"
if timeout 5 bash -c "echo > /dev/tcp/$VPCE_IP/443" 2>/dev/null; then
  echo -e "${GREEN}✓ Can connect to port 443${NC}"
else
  echo -e "${RED}✗ Cannot connect to port 443${NC}"
  echo "This could be a security group or network ACL issue"
fi
echo ""

# Test 5: Curl with IP (bypassing DNS)
echo -e "${YELLOW}Test 5: Direct HTTPS request to VPC endpoint IP${NC}"
RESPONSE=$(curl -k -s --max-time 5 -w "\nHTTP_CODE:%{http_code}" \
  --resolve "${API_ID}.execute-api.${REGION}.amazonaws.com:443:${VPCE_IP}" \
  "https://${API_ID}.execute-api.${REGION}.amazonaws.com/dev/weather?q=33418" \
  -H "accept: application/json" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')

echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" == "200" ]; then
  echo -e "${GREEN}✓ API call successful via IP!${NC}"
  echo "Response preview:"
  echo "$BODY" | head -n 5
elif [ "$HTTP_CODE" == "403" ]; then
  echo -e "${YELLOW}⚠ Got 403 - Resource policy blocking (expected from outside VPC)${NC}"
elif [ -z "$HTTP_CODE" ] || [ "$HTTP_CODE" == "000" ]; then
  echo -e "${RED}✗ Connection failed${NC}"
  echo "Error: $BODY"
else
  echo -e "${YELLOW}⚠ Unexpected response${NC}"
  echo "$BODY"
fi
echo ""

# Test 6: Curl with DNS
echo -e "${YELLOW}Test 6: HTTPS request via VPC endpoint DNS${NC}"
RESPONSE2=$(curl -s --max-time 5 -w "\nHTTP_CODE:%{http_code}" \
  "https://${VPCE_DNS}/dev/weather?q=33418" \
  -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com" \
  -H "accept: application/json" 2>&1)

HTTP_CODE2=$(echo "$RESPONSE2" | grep "HTTP_CODE" | cut -d: -f2)
echo "HTTP Status: $HTTP_CODE2"

if [ "$HTTP_CODE2" == "200" ]; then
  echo -e "${GREEN}✓ API call successful via DNS!${NC}"
elif [ -z "$HTTP_CODE2" ] || [ "$HTTP_CODE2" == "000" ]; then
  echo -e "${RED}✗ Connection failed via DNS${NC}"
else
  echo -e "${YELLOW}⚠ Got response: $HTTP_CODE2${NC}"
fi
echo ""

echo "=== Diagnostics Complete ==="
