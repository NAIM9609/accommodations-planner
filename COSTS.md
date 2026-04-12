# 💰 Cost Analysis — Accommodations Planner

All services are chosen to minimize cost for low-traffic B&B usage. Estimated monthly cost for dev/staging: **~$0–$2**.

---

## AWS Service Cost Breakdown

### AWS Lambda
- **Configuration**: 128 MB memory, 10-second timeout, `nodejs20.x`
- **Billing**: Pay-per-invocation (no idle cost)
- **Free tier**: 1M requests/month + 400,000 GB-seconds/month (never expires)
- **Estimated cost**: ~$0 for a typical B&B (< 10,000 reservations/month)
- **What increases cost**: High request volume, long execution times, large memory

### Amazon DynamoDB
- **Configuration**: `PAY_PER_REQUEST` (on-demand) billing mode — no provisioned capacity
- **Free tier**: 25 GB storage + 25 WCU/RCU provisioned (but we use on-demand)
- **On-demand pricing**: $1.25 per million write requests, $0.25 per million read requests
- **Estimated cost**: ~$0 for low traffic (< 100,000 reads/month)
- **What increases cost**: High read/write volume, large item sizes (> 1 KB per item), DynamoDB Streams

### Amazon API Gateway (REST API)
- **Free tier**: 1 million API calls/month for the first 12 months
- **After free tier**: $3.50 per million API calls
- **Estimated cost**: ~$0 during free tier; ~$0.35/month for 100k requests after
- **What increases cost**: High request volume, data transfer out (rare), caching

### AWS Amplify Hosting
- **Free tier**: 1,000 build minutes/month, 5 GB storage, 15 GB data transfer/month
- **Beyond free tier**: $0.01/build minute, $0.023/GB storage, $0.15/GB transfer
- **Estimated cost**: ~$0 for small apps with infrequent deployments
- **What increases cost**: Many deployments, large bundle sizes, high traffic

### Amazon CloudWatch Logs
- **Configuration**: **5-day log retention** on all Lambda and API Gateway log groups
- **Why 5 days**: Balances observability with cost; logs older than 5 days rarely needed for debugging
- **Free tier**: 5 GB ingestion/month, 5 GB storage/month
- **Estimated cost**: ~$0 for low traffic
- **What increases cost**: Verbose logging (e.g., logging full request/response bodies), high request volume

### S3 (Terraform State)
- **Usage**: Stores `.tfstate` files (typically < 100 KB each)
- **Free tier**: 5 GB storage, 20,000 GET, 2,000 PUT requests/month
- **Estimated cost**: ~$0.00–$0.01/month for small state files
- **What increases cost**: Frequent `terraform plan/apply` runs, large state files

### DynamoDB (Terraform State Lock)
- **Usage**: Single table for Terraform state locking (on-demand)
- **Estimated cost**: ~$0 (< 100 lock/unlock operations per month)

---

## Total Estimated Monthly Cost

| Environment | Estimated Cost | Notes |
|-------------|---------------|-------|
| Dev | ~$0/month | Free tier covers everything |
| Prod (low traffic) | ~$0–$2/month | Depending on request volume |
| Prod (medium traffic, 1M req/month) | ~$3–$8/month | Post free-tier API Gateway |

---

## Cost Optimization Decisions

| Decision | Rationale |
|----------|-----------|
| Lambda 128 MB memory | Minimum viable for Node.js; simple CRUD doesn't need more |
| DynamoDB `PAY_PER_REQUEST` | No wasted capacity for variable/low traffic |
| 5-day CloudWatch retention | Avoid log storage accumulation; sufficient for debugging |
| No NAT Gateway | Lambda runs without VPC to avoid ~$32/month NAT cost |
| No ElastiCache | DynamoDB latency is acceptable for B&B use case |
| Amplify SSG (not SSR) | Static generation avoids Amplify SSR compute costs |
| API Gateway REST (not HTTP API) | Free tier applies; HTTP API has no free tier |

---

## What Can Significantly Increase Costs

1. **High traffic**: > 1M API calls/month will incur API Gateway charges
2. **Verbose logging**: Logging full JSON bodies generates significant CloudWatch ingestion costs
3. **DynamoDB hot partitions**: Lots of writes to the same partition key increases costs
4. **Large DynamoDB items**: Items > 1 KB consume multiple read/write units
5. **Amplify SSR mode**: Switching to server-side rendering incurs compute charges
6. **Adding a NAT Gateway**: Required if Lambda needs VPC + internet access (~$32/month)
7. **Enabling X-Ray tracing**: Adds per-trace cost (~$5 per million traces)
