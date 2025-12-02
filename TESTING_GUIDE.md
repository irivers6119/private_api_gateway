# Testing the Private API Gateway

## Why the Test Failed

The test script failed with `403 Forbidden` because **AWS CloudShell runs outside your VPC** and cannot access the private API Gateway. This is actually **correct behavior** - it proves your API is properly secured!

### The Error You Saw:
```
HTTP Status: 403
✗ Failed
{"message":"Forbidden"}
```

This happens because:
1. ✅ Your API Gateway is configured as **PRIVATE**
2. ✅ The resource policy only allows traffic from VPC Endpoint `vpce-0df7e09a0bc49a117`
3. ✅ CloudShell is outside the VPC, so it's correctly blocked

## How to Test the Private API

You have **two options** to test your private API:

---

## Option 1: Launch EC2 Instance in the VPC (Recommended)

### Step 1: Launch EC2 Instance

```bash
# Get the VPC ID and Subnet ID
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name weather-api-private-dev \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
  --output text)

SUBNET_ID=$(aws cloudformation describe-stacks \
  --stack-name weather-api-private-dev \
  --query "Stacks[0].Outputs[?OutputKey=='PrivateSubnetId'].OutputValue" \
  --output text)

# Create a security group for the test instance
SG_ID=$(aws ec2 create-security-group \
  --group-name weather-api-test-sg \
  --description "Security group for testing private API" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow SSH access (adjust source CIDR as needed)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Launch EC2 instance (Amazon Linux 2023)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=weather-api-test}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
echo "Waiting for instance to be ready..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
```

### Step 2: Connect to EC2 Instance

```bash
# Get the public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# Connect using EC2 Instance Connect or SSH
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID
```

### Step 3: Run the Test Script on EC2

```bash
# On the EC2 instance, download the test script
cat > test-api.sh << 'EOF'
#!/bin/bash

# Configuration
API_ID="609x52qn26"
VPC_ENDPOINT_ID="vpce-0df7e09a0bc49a117"
REGION="us-east-1"
STAGE="dev"

# Construct the API endpoint URL
API_URL="https://${API_ID}-${VPC_ENDPOINT_ID}.execute-api.${REGION}.vpce.amazonaws.com/${STAGE}/weather"

echo "Testing API: $API_URL"
echo ""

# Test 1: Get weather for zip code 33418
echo "Test 1: Weather for 33418"
curl -X GET "${API_URL}?q=33418&lang=en-US" \
  -H "accept: application/json" \
  -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com" | python3 -m json.tool

echo ""
echo ""

# Test 2: Get weather for Miami
echo "Test 2: Weather for Miami"
curl -X GET "${API_URL}?q=Miami&lang=en-US" \
  -H "accept: application/json" \
  -H "Host: ${API_ID}.execute-api.${REGION}.amazonaws.com" | python3 -m json.tool
EOF

chmod +x test-api.sh
./test-api.sh
```

---

## Option 2: Use Systems Manager Session Manager

If you don't want to deal with SSH keys, use AWS Systems Manager:

### Step 1: Launch EC2 with SSM Role

```bash
# Create IAM role for SSM (if not exists)
aws iam create-role \
  --role-name EC2-SSM-Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach SSM policy
aws iam attach-role-policy \
  --role-name EC2-SSM-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create instance profile
aws iam create-instance-profile --instance-profile-name EC2-SSM-Profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-SSM-Profile \
  --role-name EC2-SSM-Role

# Launch instance with SSM role
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --subnet-id $SUBNET_ID \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=EC2-SSM-Profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=weather-api-test}]' \
  --query 'Instances[0].InstanceId' \
  --output text)
```

### Step 2: Connect via Session Manager

```bash
# Connect to instance
aws ssm start-session --target $INSTANCE_ID

# Then run the test commands inside the session
```

---

## Quick Test Commands

Once connected to the EC2 instance, run these commands:

### Test 1: Weather by Zip Code
```bash
curl -X GET \
  "https://609x52qn26-vpce-0df7e09a0bc49a117.execute-api.us-east-1.vpce.amazonaws.com/dev/weather?q=33418" \
  -H "Host: 609x52qn26.execute-api.us-east-1.amazonaws.com" \
  -H "accept: application/json"
```

### Test 2: Weather by City
```bash
curl -X GET \
  "https://609x52qn26-vpce-0df7e09a0bc49a117.execute-api.us-east-1.vpce.amazonaws.com/dev/weather?q=Miami" \
  -H "Host: 609x52qn26.execute-api.us-east-1.amazonaws.com" \
  -H "accept: application/json"
```

### Test 3: Error Handling
```bash
curl -X GET \
  "https://609x52qn26-vpce-0df7e09a0bc49a117.execute-api.us-east-1.vpce.amazonaws.com/dev/weather" \
  -H "Host: 609x52qn26.execute-api.us-east-1.amazonaws.com" \
  -H "accept: application/json"
```

Expected: `{"error":"Missing required parameter: q (location)"}`

---

## Enhanced Test Script

I've created an enhanced test script (`test-from-ec2.sh`) that you can copy to your EC2 instance. It includes:

- ✅ Formatted output with colors
- ✅ Multiple test scenarios
- ✅ Error handling verification
- ✅ Test summary

To use it on EC2:

```bash
# Copy the script content (from test-from-ec2.sh) to EC2
nano test-from-ec2.sh
# Paste the content

# Make it executable
chmod +x test-from-ec2.sh

# Run it
./test-from-ec2.sh
```

---

## Why This Design is Secure

✅ **Private API Gateway**: Not accessible from public internet  
✅ **VPC Endpoint Only**: Must route through specific VPC endpoint  
✅ **Resource Policy**: Explicitly restricts access to VPC endpoint  
✅ **CloudShell Blocked**: External access properly denied (403 Forbidden)  

The `403 Forbidden` error you received is **proof that your security is working correctly**! 🎉

---

## Cleanup After Testing

```bash
# Terminate the test EC2 instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Delete the security group (after instance is terminated)
aws ec2 delete-security-group --group-id $SG_ID
```
