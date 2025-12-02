# Weather API Private Gateway

A private API Gateway using AWS Serverless Framework with VPC endpoint connectivity. This project creates a secure, private API that proxies requests to the WeatherAPI service.

## Architecture

- **Private API Gateway**: Accessible only through VPC endpoint
- **VPC Endpoint**: Interface endpoint for API Gateway in private subnet
- **Lambda Function**: Node.js proxy that calls WeatherAPI
- **VPC**: Custom VPC with public and private subnets
- **NAT Gateway**: Allows Lambda in private subnet to reach external APIs

# Private API Gateway Architecture

## ENIs and Traffic Flow

The diagram below illustrates how traffic flows when using a **Private API Gateway**:

- **EC2 instance** in a private subnet sends traffic to the **VPC Endpoint ENI**.
- The **Interface VPC Endpoint** creates ENIs in the subnets you select (one per subnet).
- Traffic flows through these ENIs to the **Private API Gateway**, staying inside the VPC and AWS private network.
- No public internet is involved.

### IP Usage Details
- Each VPC Endpoint ENI consumes **1 IP address** from its associated subnet.
- API Gateway itself does **not** consume IPs from your subnets.

### Security Controls
- Use **resource policies** on API Gateway to restrict access to your VPC endpoint.
- Apply **security groups** to the VPC endpoint ENIs for fine-grained control.



## Prerequisites

- AWS CLI configured with default profile
- Node.js 18+ and npm
- Serverless Framework
- Valid WeatherAPI key

## Environment Variables

Create a `.env` file in the project root:

```
SERVERLESS_ACCESS_KEY=your_serverless_access_key
WEATHER_API_KEY=your_weather_api_key
```

## Installation

1. Install dependencies:
```bash
npm install
```

2. Deploy the stack:
```bash
npm run deploy
```

This will create:
- VPC with public and private subnets
- NAT Gateway for outbound connectivity
- API Gateway with private endpoint type
- VPC Endpoint for API Gateway
- Lambda function in private subnet
- Security groups and route tables

## Deployment

Deploy to AWS:
```bash
serverless deploy
```

Deploy to specific region:
```bash
serverless deploy --region us-west-2
```

## API Usage

### Endpoint

The API is private and can only be accessed from within the VPC through the VPC endpoint.

### Request Format

```
GET /weather?q={location}&lang={language}
```

Parameters:
- `q` (required): Location (zip code, city name, coordinates)
- `lang` (optional): Language code (default: en-US)

### Example Request

```bash
curl -X GET \
  "https://{api-id}.execute-api.{region}.amazonaws.com/dev/weather?q=33418&lang=en-US" \
  -H "accept: application/json"
```

### Example Response

```json
{
  "location": {
    "name": "Palm Beach Gardens",
    "region": "Florida",
    "country": "USA",
    "lat": 26.82,
    "lon": -80.14,
    "tz_id": "America/New_York",
    "localtime": "2025-12-01 21:25"
  },
  "current": {
    "temp_c": 24.4,
    "temp_f": 75.9,
    "condition": {
      "text": "Partly cloudy"
    },
    "humidity": 79,
    "wind_mph": 12.1
  }
}
```

## Testing from AWS CloudShell

1. Launch CloudShell in your AWS account
2. Upload the test script:
```bash
# In CloudShell
curl -o test-private-api.sh https://raw.githubusercontent.com/your-repo/test-private-api.sh
chmod +x test-private-api.sh
```

3. Run the test:
```bash
./test-private-api.sh
```

Note: CloudShell must be in the same VPC or have connectivity to the VPC endpoint.

## Testing from EC2 Instance in VPC

If you need to test from an EC2 instance:

1. Launch an EC2 instance in the same VPC (can use the private subnet)
2. Copy the test script to the instance
3. Run the test script:
```bash
chmod +x test-private-api.sh
./test-private-api.sh
```

## Monitoring

View Lambda logs:
```bash
serverless logs -f weatherProxy -t
```

Or using AWS CLI:
```bash
aws logs tail /aws/lambda/weather-api-private-dev-weatherProxy --follow
```

## Cleanup

Remove all resources:
```bash
serverless remove
```

Or:
```bash
npm run remove
```

## Architecture Details

### Network Configuration

- **VPC CIDR**: 10.0.0.0/16
- **Private Subnet**: 10.0.1.0/24
- **Public Subnet**: 10.0.2.0/24 (for NAT Gateway)

### Security

- Lambda runs in private subnet with no public IP
- Outbound internet access through NAT Gateway
- API Gateway is private and requires VPC endpoint
- Resource policy restricts access to specific VPC endpoint
- Security groups control network traffic

### Cost Considerations

- NAT Gateway: ~$0.045/hour + data transfer
- VPC Endpoint: ~$0.01/hour + data transfer
- Lambda: Pay per request and duration
- API Gateway: Pay per request

## Troubleshooting

### Lambda timeout or connection issues

- Check NAT Gateway is running
- Verify route tables are configured correctly
- Ensure security groups allow outbound HTTPS

### Cannot access API

- Verify you're calling from within the VPC
- Check VPC endpoint is active
- Verify resource policy on API Gateway

### Weather API errors

- Check WEATHER_API_KEY is set correctly
- Verify API key is valid
- Check Lambda logs for detailed errors

## License

MIT
