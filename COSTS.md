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

### Amazon API Gateway (HTTP API)
- **Free tier**: None (HTTP API does not have a free tier, unlike REST API)
- **Pricing**: $1.00 per million requests (first 300M/month); $0.90/M up to 1B; $0.80/M over 1B
- **Estimated cost**: ~$0.10/month for 100k requests; ~$1.00/month for 1M requests
- **What increases cost**: High request volume, data transfer out (rare)

### AWS Amplify Hosting
- **Free tier**: 1,000 build minutes/month, 5 GB storage, 15 GB data transfer/month
- **Beyond free tier**: $0.01/build minute, $0.023/GB storage, $0.15/GB transfer
- **Estimated cost**: ~$0 for small apps with infrequent deployments
- **What increases cost**: Many deployments, large bundle sizes, high traffic

### Amazon CloudWatch Logs
- **Configuration**: **3-day log retention** (default; configurable via `cloudwatch_log_retention_days`; `prod.tfvars` uses 1 day) on all Lambda log groups
- **Why short retention**: Balances observability with cost; avoids log storage accumulation; adjust via `cloudwatch_log_retention_days` variable
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
| 3-day CloudWatch retention (default) | Avoid log storage accumulation; sufficient for debugging; prod uses 1 day |
| No NAT Gateway | Lambda runs without VPC to avoid ~$32/month NAT cost |
| No ElastiCache | DynamoDB latency is acceptable for B&B use case |
| Amplify SSG (not SSR) | Static generation avoids Amplify SSR compute costs |
| API Gateway HTTP API (not REST API) | Lower per-request cost ($1.00/M vs $3.50/M for REST); note: no free tier |

---

## What Can Significantly Increase Costs

1. **High traffic**: > 1M API calls/month will incur API Gateway charges
2. **Verbose logging**: Logging full JSON bodies generates significant CloudWatch ingestion costs
3. **DynamoDB hot partitions**: Lots of writes to the same partition key increases costs
4. **Large DynamoDB items**: Items > 1 KB consume multiple read/write units
5. **Amplify SSR mode**: Switching to server-side rendering incurs compute charges
6. **Adding a NAT Gateway**: Required if Lambda needs VPC + internet access (~$32/month)
7. **Enabling X-Ray tracing**: Adds per-trace cost (~$5 per million traces)
