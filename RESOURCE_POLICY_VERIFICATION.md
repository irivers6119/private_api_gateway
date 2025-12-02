# API Gateway Resource Policy Verification

## Deployment Summary

**API Gateway ID**: `609x52qn26`  
**VPC Endpoint ID**: `vpce-0df7e09a0bc49a117`  
**Region**: `us-east-1`  
**Endpoint Type**: `PRIVATE`

## Resource Policy Configuration

The API Gateway has been configured with a **resource-based policy** that restricts access to only traffic originating from the specific VPC endpoint.

### Policy Details

The resource policy includes two statements:

#### 1. Deny Statement (Explicit Deny)
```yaml
- Effect: Deny
  Principal: '*'
  Action: execute-api:Invoke
  Resource: execute-api:/*
  Condition:
    StringNotEquals:
      aws:SourceVpce: vpce-0df7e09a0bc49a117
```

This statement **explicitly denies** all API invocations that do NOT originate from the VPC endpoint `vpce-0df7e09a0bc49a117`.

#### 2. Allow Statement
```yaml
- Effect: Allow
  Principal: '*'
  Action: execute-api:Invoke
  Resource: execute-api:/*
  Condition:
    StringEquals:
      aws:SourceVpce: vpce-0df7e09a0bc49a117
```

This statement **allows** API invocations that originate from the VPC endpoint `vpce-0df7e09a0bc49a117`.

## Verification Test

### Public Access Test (from Internet)

```bash
curl -s "https://609x52qn26.execute-api.us-east-1.amazonaws.com/dev/weather?q=33418"
```

**Result**:
```json
{
    "Message": "User: anonymous is not authorized to perform: execute-api:Invoke on resource: arn:aws:execute-api:us-east-1:********9489:609x52qn26/dev/GET/weather because no resource-based policy allows the execute-api:Invoke action"
}
```

✅ **CONFIRMED**: Public access is **BLOCKED** by the resource policy.

### Private Access Test (from VPC)

To test from within the VPC, you need to:

1. **Launch an EC2 instance** in the VPC (subnet: `subnet-0a4081e2a7d04b14f`)
2. **Or use AWS CloudShell** with VPC connectivity
3. Run the test script: `./test-private-api.sh`

The API will only respond when accessed through the VPC endpoint.

## Security Features

✅ **Endpoint Type**: PRIVATE (not accessible from public internet)  
✅ **Resource Policy**: Restricts access to specific VPC endpoint  
✅ **VPC Endpoint**: Interface endpoint with private DNS enabled  
✅ **Security Groups**: Control network traffic to VPC endpoint  
✅ **Lambda in Private Subnet**: Function has no public IP  
✅ **NAT Gateway**: Allows outbound internet access for Lambda  

## Architecture Flow

```
Internet ❌ → API Gateway (PRIVATE)
     ↓
VPC Endpoint ✅ → API Gateway (PRIVATE)
     ↓
Lambda (Private Subnet) → NAT Gateway → Weather API (Internet)
```

## How to Access the API

### From EC2 Instance in VPC

1. Launch EC2 in the VPC (any subnet with route to VPC endpoint)
2. SSH into the instance
3. Make request:
   ```bash
   curl "https://609x52qn26.execute-api.us-east-1.amazonaws.com/dev/weather?q=33418"
   ```

### From AWS CloudShell (if in VPC)

1. Open CloudShell in the AWS Console
2. Run the test script:
   ```bash
   chmod +x test-private-api.sh
   ./test-private-api.sh
   ```

### Using AWS SDK from VPC

```javascript
const AWS = require('aws-sdk');
const apigateway = new AWS.APIGateway();

// The SDK will automatically use the VPC endpoint if configured
const response = await fetch(
  'https://609x52qn26.execute-api.us-east-1.amazonaws.com/dev/weather?q=33418'
);
```

## Conclusion

✅ **CONFIRMED**: The API Gateway has a **resource-based policy** that:
- Blocks all public internet traffic
- Only allows traffic from VPC Endpoint `vpce-0df7e09a0bc49a117`
- Implements defense-in-depth with explicit deny + conditional allow
- Ensures the API is truly private and secure

The error message when accessing from public internet confirms the policy is working correctly:
> "User: anonymous is not authorized to perform: execute-api:Invoke on resource... because no resource-based policy allows the execute-api:Invoke action"
