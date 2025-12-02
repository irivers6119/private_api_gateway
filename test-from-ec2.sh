#!/bin/bash

# EC2 Test script for private API Gateway
# This script should be run from an EC2 instance in the VPC

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Private API Gateway EC2 Test Script ===${NC}\n"

# Configuration - Update these values
API_ID="609x52qn26"
VPCE_ENDPOINT_ID="vpce-0df7e09a0bc49a117"
REGION="us-east-1"
STAGE="dev"

echo -e "${GREEN}Configuration:${NC}"
echo -e "  API ID: ${API_ID}"
echo -e "  VPC Endpoint: ${VPCE_ENDPOINT_ID}"
echo -e "  Region: ${REGION}"
echo ""

# Construct the API endpoint URL using VPC Endpoint DNS
API_URL="https://${API_ID}-${VPC_ENDPOINT_ID}.execute-api.${REGION}.vpce.amazonaws.com/${STAGE}/weather"

echo -e "${YELLOW}API Endpoint:${NC} $API_URL"
echo ""

# Test 1: Basic weather request with zip code
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 1: Weather request for zip code 33418${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X GET "${API_URL}?q=33418&lang=en-US" \
  -H "accept: application/json" \
  -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE/d')

echo -e "${GREEN}HTTP Status:${NC} $HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
  echo -e "${GREEN}✓ Test Passed!${NC}"
  echo ""
  echo -e "${YELLOW}Location Information:${NC}"
  
  # Extract and display key information
  LOCATION=$(echo "$BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); loc=data.get('location', {}); print(f\"{loc.get('name', 'N/A')}, {loc.get('region', 'N/A')}, {loc.get('country', 'N/A')}\")" 2>/dev/null)
  TEMP_F=$(echo "$BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('current', {}).get('temp_f', 'N/A'))" 2>/dev/null)
  CONDITION=$(echo "$BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('current', {}).get('condition', {}).get('text', 'N/A'))" 2>/dev/null)
  HUMIDITY=$(echo "$BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('current', {}).get('humidity', 'N/A'))" 2>/dev/null)
  
  echo -e "  📍 Location: ${LOCATION}"
  echo -e "  🌡️  Temperature: ${TEMP_F}°F"
  echo -e "  ☁️  Condition: ${CONDITION}"
  echo -e "  💧 Humidity: ${HUMIDITY}%"
  echo ""
  echo -e "${YELLOW}Full Response:${NC}"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
else
  echo -e "${RED}✗ Test Failed${NC}"
  echo ""
  echo -e "${RED}Response:${NC}"
  echo "$BODY"
fi

echo ""

# Test 2: Weather request for a city
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 2: Weather request for Miami, FL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
RESPONSE2=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X GET "${API_URL}?q=Miami&lang=en-US" \
  -H "accept: application/json" \
  -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com")

HTTP_CODE2=$(echo "$RESPONSE2" | grep "HTTP_CODE" | cut -d: -f2)
BODY2=$(echo "$RESPONSE2" | sed '/HTTP_CODE/d')

echo -e "${GREEN}HTTP Status:${NC} $HTTP_CODE2"

if [ "$HTTP_CODE2" == "200" ]; then
  echo -e "${GREEN}✓ Test Passed!${NC}"
  echo ""
  
  # Extract and display key information
  LOCATION2=$(echo "$BODY2" | python3 -c "import sys, json; data=json.load(sys.stdin); loc=data.get('location', {}); print(f\"{loc.get('name', 'N/A')}, {loc.get('region', 'N/A')}\")" 2>/dev/null)
  TEMP_F2=$(echo "$BODY2" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('current', {}).get('temp_f', 'N/A'))" 2>/dev/null)
  CONDITION2=$(echo "$BODY2" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('current', {}).get('condition', {}).get('text', 'N/A'))" 2>/dev/null)
  
  echo -e "  📍 Location: ${LOCATION2}"
  echo -e "  🌡️  Temperature: ${TEMP_F2}°F"
  echo -e "  ☁️  Condition: ${CONDITION2}"
else
  echo -e "${RED}✗ Test Failed${NC}"
  echo ""
  echo -e "${RED}Response:${NC}"
  echo "$BODY2"
fi

echo ""

# Test 3: Error handling - missing parameter
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Test 3: Error handling (missing required parameter)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
RESPONSE3=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X GET "${API_URL}" \
  -H "accept: application/json" \
  -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com")

HTTP_CODE3=$(echo "$RESPONSE3" | grep "HTTP_CODE" | cut -d: -f2)
BODY3=$(echo "$RESPONSE3" | sed '/HTTP_CODE/d')

echo -e "${GREEN}HTTP Status:${NC} $HTTP_CODE3"

if [ "$HTTP_CODE3" == "400" ]; then
  echo -e "${GREEN}✓ Error handling works correctly!${NC}"
  echo ""
  echo "$BODY3" | python3 -m json.tool 2>/dev/null || echo "$BODY3"
else
  echo -e "${YELLOW}⚠ Unexpected status code (expected 400)${NC}"
  echo ""
  echo "$BODY3"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}=== Testing Complete ===${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Summary
PASSED=0
FAILED=0

[ "$HTTP_CODE" == "200" ] && ((PASSED++)) || ((FAILED++))
[ "$HTTP_CODE2" == "200" ] && ((PASSED++)) || ((FAILED++))
[ "$HTTP_CODE3" == "400" ] && ((PASSED++)) || ((FAILED++))

echo -e "${YELLOW}Test Summary:${NC}"
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
echo -e "  ${RED}Failed: ${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed. Please check the output above.${NC}"
  exit 1
fi
