# Quick Start Deployment Guide

## Step 1: Verify Environment Variables

Your `.env` file should contain:
```
SERVERLESS_ACCESS_KEY=AKljGG0PHW7SxYMz0XldMWLfOA0D67R6ZD1XKUhLVzmir
WEATHER_API_KEY=f881dc9f49ab487d84022400250212
```

## Step 2: Deploy to AWS

```bash
# Deploy the entire stack
npm run deploy

# Or use serverless directly
serverless deploy --verbose
```

The deployment will create:
- ✅ VPC (10.0.0.0/16)
- ✅ Private Subnet (10.0.1.0/24)
- ✅ Public Subnet (10.0.2.0/24)
- ✅ Internet Gateway
- ✅ NAT Gateway
- ✅ API Gateway (Private)
- ✅ VPC Endpoint for API Gateway
- ✅ Lambda Function (weatherProxy)
- ✅ Security Groups
- ✅ Route Tables

**Note**: Deployment takes 5-10 minutes due to NAT Gateway creation.

## Step 3: Get API Information

After deployment completes, you'll see outputs including:
- API ID
- VPC Endpoint ID
- API Endpoint URL

Save these for testing!

## Step 4: Test from AWS CloudShell

### Option A: From CloudShell in a VPC-connected Environment

1. Open AWS CloudShell in your AWS Console
2. Upload the test script:
   ```bash
   # Copy the content of test-private-api.sh to CloudShell
   nano test-private-api.sh
   # Paste the content, save (Ctrl+O, Enter, Ctrl+X)
   
   # Make executable
   chmod +x test-private-api.sh
   
   # Run the test
   ./test-private-api.sh
   ```

### Option B: Manual Test with curl

Replace `{API_ID}` and `{REGION}` with your values:

```bash
# Get your API details
aws cloudformation describe-stacks \
  --stack-name weather-api-private-dev \
  --query "Stacks[0].Outputs"

# Test the API
curl -X GET \
  "https://{API_ID}.execute-api.{REGION}.amazonaws.com/dev/weather?q=33418&lang=en-US" \
  -H "accept: application/json"
```

### Option C: Test from EC2 Instance in VPC

If CloudShell doesn't have VPC access, you'll need to:

1. Launch an EC2 instance in the same VPC
2. SSH into the instance
3. Copy and run the test script

```bash
# On EC2 instance
aws cloudformation describe-stacks --stack-name weather-api-private-dev

# Test
API_ID="your-api-id"
REGION="your-region"

curl -X GET \
  "https://${API_ID}.execute-api.${REGION}.amazonaws.com/dev/weather?q=33418" \
  -H "accept: application/json"
```

## Step 5: Monitor Logs

```bash
# Real-time logs
npm run logs

# Or with serverless
serverless logs -f weatherProxy --tail

# Or with AWS CLI
aws logs tail /aws/lambda/weather-api-private-dev-weatherProxy --follow
```

## API Endpoints

### Get Weather
```
GET /weather?q={location}&lang={language}
```

**Parameters:**
- `q` (required): Location (zip code, city name, lat,lon)
- `lang` (optional): Language code (default: en-US)

**Examples:**
```bash
# By zip code
?q=33418

# By city name
?q=Miami

# By coordinates
?q=26.82,-80.14

# With language
?q=Miami&lang=es-ES
```

## Cleanup

To remove all resources and avoid charges:

```bash
npm run remove

# Or
serverless remove
```

## Troubleshooting

### Issue: Cannot access API from outside VPC
**Solution**: This is expected! The API is private. You must access it from within the VPC through the VPC endpoint.

### Issue: Lambda timeout
**Solution**: 
- Check NAT Gateway is running
- Verify route table configuration
- Check security group allows outbound HTTPS (port 443)

### Issue: 403 Forbidden
**Solution**:
- Verify you're calling from the VPC
- Check the VPC endpoint is active
- Verify resource policy allows access from your VPC endpoint

### Issue: Weather API errors
**Solution**:
- Verify WEATHER_API_KEY in .env is correct
- Check Lambda logs: `npm run logs`
- Test the Weather API key directly:
  ```bash
  curl "https://api.weatherapi.com/v1/current.json?q=Miami&key=YOUR_KEY"
  ```

## Cost Estimate

**Approximate monthly costs (assuming moderate usage):**
- NAT Gateway: ~$32/month (hourly charge)
- VPC Endpoint: ~$7/month
- Lambda: $0.20 per 1M requests + compute time
- API Gateway: $3.50 per 1M requests
- Data Transfer: Variable

**Total**: ~$40-50/month for the infrastructure + per-request charges

## Next Steps

1. ✅ Deploy the stack
2. ✅ Test the API
3. ✅ Monitor logs
4. Consider adding:
   - CloudWatch alarms
   - API caching
   - Request throttling
   - Additional Lambda functions
   - Custom domain name
