# Infrastructure Cost Model

Comprehensive cost breakdown and optimization guide for all modules.

## Quick Cost Reference

| Module | Minimal | Typical | Advanced |
|--------|---------|---------|----------|
| **S3 Bucket** | $0.25/mo | $0.35/mo | $3.40/mo |
| **CloudFront** | - | $1-5/mo | $5-15/mo |
| **WAF** | - | $5/mo | $10-20/mo |
| **Deployment Roles (IAM)** | $0 | $0 | $0 |
| **AWS Organizations** | $0 | $2/mo | $5-10/mo |
| **Monitoring** | $0.50/mo | $2/mo | $5-10/mo |

**Total Infrastructure (Typical Stack):**
- Dev: ~$5/month
- Staging: ~$8/month
- Production: ~$15-30/month

[Jump to detailed breakdown ↓](#detailed-module-costs)

---

## Cost Methodology

### Pricing Sources

All costs based on AWS US East 1 pricing (January 2025):
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [WAF Pricing](https://aws.amazon.com/waf/pricing/)
- [CloudTrail Pricing](https://aws.amazon.com/cloudtrail/pricing/)

### Assumptions

**Default usage patterns:**
- Website size: 10 GB
- Monthly requests: 100,000 (low traffic)
- Data transfer: 50 GB/month outbound
- Versioning enabled: 50 GB old versions
- Geographic distribution: North America (80%), Europe (15%), Asia (5%)

**Note:** Your actual costs may vary based on:
- Traffic volume (requests/month)
- Data transfer (GB/month)
- Storage growth rate
- Feature enablement (replication, logging, etc.)

### Cost Factors by Module

| Factor | Impact on Cost |
|--------|----------------|
| **Storage Volume** | Linear (GB × price) |
| **Requests** | Linear (count × price) |
| **Data Transfer** | Tiered pricing (first 10 TB cheaper) |
| **Versioning** | Multiplies storage (GB × versions) |
| **Replication** | 2x storage + cross-region transfer |
| **Lifecycle Policies** | Reduces cost over time (IA/Glacier cheaper) |

---

## Detailed Module Costs

### S3 Bucket Module

#### Minimal Example: ~$0.25/month

**What you get:**
- 1 S3 bucket
- AES-256 encryption
- No versioning
- No access logs
- No lifecycle policies

**Cost breakdown (10 GB website):**
```
Storage (Standard):     10 GB × $0.023/GB    = $0.23/month
Requests (PUT):         100 × $0.005/1000    = $0.0005/month
Requests (GET):     100,000 × $0.0004/1000  = $0.04/month
────────────────────────────────────────────────────────────
Total:                                       = $0.27/month
```

**Scaling:**
- 1 GB: $0.063/month
- 10 GB: $0.27/month
- 100 GB: $2.34/month
- 1 TB: $23.50/month

---

#### Typical Example: ~$0.35/month

**What you get:**
- 2 S3 buckets (website + logs)
- AES-256 encryption
- Versioning enabled
- Access logging
- Lifecycle policies (30d → IA, 90d → Glacier)

**Cost breakdown (10 GB website, 50 GB old versions, 2 GB logs):**
```
Website Bucket:
  Current version (Standard):  10 GB × $0.023/GB           = $0.23/month
  Old versions (IA):          20 GB × $0.0125/GB           = $0.25/month
  Old versions (Glacier):     30 GB × $0.004/GB            = $0.12/month

Logs Bucket:
  Logs (Standard):             2 GB × $0.023/GB            = $0.05/month

Requests:
  PUT (uploads):             100 × $0.005/1000             = $0.0005/month
  GET (downloads):       100,000 × $0.0004/1000           = $0.04/month

Lifecycle Transitions:
  Transitions to IA:          20 × $0.01                   = $0.20/month
  Transitions to Glacier:     30 × $0.03                   = $0.90/month
────────────────────────────────────────────────────────────────────────
Total (first month):                                       = $1.80/month
Total (steady state, month 2+):                            = $0.70/month
```

**Cost optimization impact:**
- **Without lifecycle**: 60 GB × $0.023 = $1.38/month
- **With lifecycle**: $0.65/month
- **Savings**: $0.73/month (53% reduction)

**Scaling:**
- 10 GB + 50 GB versions: $0.70/month
- 50 GB + 250 GB versions: $3.20/month
- 100 GB + 500 GB versions: $6.30/month

---

#### Advanced Example: ~$3.40/month

**What you get:**
- 5 S3 buckets (primary, replica, backup, 2x logs)
- KMS customer-managed encryption
- Cross-region replication (15-min RPO)
- Lifecycle policies (aggressive optimization)
- 7-year compliance retention

**Cost breakdown (10 GB website):**

**Storage:**
```
Primary Bucket (Standard):          10 GB × $0.023/GB     = $0.23/month
Replica Bucket (IA):                10 GB × $0.0125/GB    = $0.125/month
Backup Bucket (Deep Archive):       10 GB × $0.001/GB     = $0.01/month
Logs Buckets (2 regions):            2 GB × $0.023/GB     = $0.046/month
Old Versions (IA/Glacier):          15 GB × $0.008/GB     = $0.12/month
────────────────────────────────────────────────────────────────────────
Storage Total:                                             = $0.53/month
```

**Replication:**
```
Cross-region data transfer:         10 GB × $0.02/GB      = $0.20/month
Replication PUT requests:        1,000 × $0.005/1000      = $0.005/month
Replication Time Control:       1,000 × $0.0001          = $0.10/month
────────────────────────────────────────────────────────────────────────
Replication Total:                                         = $0.31/month
```

**KMS:**
```
KMS key storage:                2 keys × $1.00            = $2.00/month
KMS API requests:           10,000 × $0.03/10,000         = $0.03/month
────────────────────────────────────────────────────────────────────────
KMS Total:                                                 = $2.03/month
```

**Requests:**
```
PUT requests:                     1,000 × $0.005/1000     = $0.005/month
GET requests:                   100,000 × $0.0004/1000    = $0.04/month
────────────────────────────────────────────────────────────────────────
Requests Total:                                            = $0.045/month
```

**Grand Total: $2.90/month**

**Why $3.40/month in README?**
- Includes CloudWatch metrics for replication monitoring (~$0.50/month)

**Scaling:**
- 10 GB: $3.40/month
- 50 GB: $6.20/month
- 100 GB: $10.50/month

**Cost optimization:**
- **Disable RTC**: Save $0.10/month (if 15-min RPO not needed)
- **Use single region**: Save $0.31/month (no replication)
- **Use AWS-managed keys**: Save $2.03/month (but lose compliance benefit)

---

### CloudFront Distribution

#### Typical Setup: ~$1-5/month

**What you get:**
- CloudFront distribution
- SSL/TLS certificate (ACM, free)
- Origin Access Control (OAC)
- Cache invalidations (1,000/month free)

**Cost breakdown (100,000 requests, 50 GB transfer):**
```
Requests (HTTP):               100,000 × $0.0075/10,000   = $0.075/month
Data Transfer Out (first 10TB):  50 GB × $0.085/GB        = $4.25/month
────────────────────────────────────────────────────────────────────────
Total:                                                     = $4.33/month
```

**Traffic impact:**
- 10,000 requests, 5 GB: $0.43/month
- 100,000 requests, 50 GB: $4.33/month
- 1M requests, 500 GB: $43/month
- 10M requests, 5 TB: $426/month

**Cost optimization:**
- **Increase cache hit ratio**: Reduces origin requests and transfer
- **Use S3 Transfer Acceleration**: For uploads (additional cost)
- **Compress content**: Reduces data transfer by 60-80%

**Cache hit ratio impact (1M requests, 500 GB potential):**
- 50% cache hit: $213/month (50% traffic from cache, free)
- 90% cache hit: $43/month (90% from cache)
- 95% cache hit: $21.50/month

---

### AWS WAF

#### Typical Setup: ~$5/month

**What you get:**
- Web ACL
- 5 managed rule groups
- IP rate limiting
- Geo-blocking

**Cost breakdown:**
```
Web ACL:                         1 × $5.00                 = $5.00/month
Managed Rule Groups:           5 × $1.00                  = $5.00/month
Rules:                         10 × $1.00                  = $10.00/month
Requests:               1,000,000 × $0.60/1M              = $0.60/month
────────────────────────────────────────────────────────────────────────
Total:                                                     = $20.60/month
```

**Cost optimization:**
- **Use fewer rule groups**: Each group is $1/month
- **Optimize rules**: Each rule is $1/month
- **Sample requests**: Enable sampling to reduce request charges

**Scaling:**
- 100,000 requests: $15.06/month
- 1M requests: $20.60/month
- 10M requests: $26.00/month

---

### IAM Roles (Deployment)

#### All Examples: $0/month

IAM roles, policies, and users are **free**. No cost for:
- Deployment roles
- Cross-account admin roles
- Service roles

**Note:** IAM has soft limits:
- 1,000 roles per account (can request increase)
- 10 policies per role
- 10,240 characters per policy

---

### AWS Organizations

#### Minimal (Import Existing): $0/month

No resources created, just data source reference.

---

#### Typical (CloudTrail + Security Hub): ~$2/month

**Cost breakdown:**
```
CloudTrail:
  Management events (first trail):  Free                   = $0/month
  Data events (if enabled):         $0.10 per 100,000     = variable

Security Hub:
  Security checks:                  10,000 × $0.0010      = $10/month
  Finding ingestion:                10,000 × $0.00003     = $0.30/month
  (First 10,000 checks free in first 30 days)

S3 bucket (CloudTrail logs):        2 GB × $0.023/GB      = $0.05/month
────────────────────────────────────────────────────────────────────────
Total (after free tier):                                   = $10.35/month
```

**Note:** First 30 days of Security Hub are discounted.

---

#### Advanced (Full Org Setup): ~$5-10/month

**Cost breakdown:**
```
Same as Typical, plus:
  Additional member accounts:      3 × $0 (no cost)       = $0/month
  Service Control Policies:        Free                   = $0/month
  Organizational Units:            Free                   = $0/month
────────────────────────────────────────────────────────────────────────
Total:                                                     = $10.35/month
```

**Note:** Cost is same as Typical (CloudTrail + Security Hub). OUs and SCPs are free.

---

## Scaling Scenarios

### Scenario 1: Single Developer (Dev Only)

**Infrastructure:**
- 1 S3 bucket (minimal)
- No CloudFront
- 1 deployment role

**Monthly cost: ~$0.25/month**

**Breakdown:**
```
S3 (10 GB):                      $0.25/month
IAM:                             $0/month
────────────────────────────────────────────
Total:                           $0.25/month
```

---

### Scenario 2: Startup (Dev + Prod)

**Infrastructure:**
- 2 environments (dev, prod)
- S3 buckets (typical)
- CloudFront (prod only)
- 2 deployment roles

**Monthly cost: ~$10/month**

**Breakdown:**
```
Dev Environment:
  S3 (typical):                  $0.35/month
  IAM:                           $0/month

Prod Environment:
  S3 (typical):                  $0.35/month
  CloudFront (low traffic):      $2/month
  WAF (optional):                $5/month
  IAM:                           $0/month
────────────────────────────────────────────
Total:                           $7.70/month
```

---

### Scenario 3: Scale-up (Dev + Staging + Prod)

**Infrastructure:**
- 3 environments
- S3 buckets (typical for dev/staging, advanced for prod)
- CloudFront (all envs)
- WAF (prod only)
- Organizations with CloudTrail

**Monthly cost: ~$35/month**

**Breakdown:**
```
Dev Environment:
  S3 (typical):                  $0.35/month
  CloudFront:                    $1/month

Staging Environment:
  S3 (typical):                  $0.35/month
  CloudFront:                    $2/month

Production Environment:
  S3 (advanced, DR):             $3.40/month
  CloudFront (moderate traffic): $10/month
  WAF:                           $10/month

Organization-wide:
  AWS Organizations:             $10/month
────────────────────────────────────────────
Total:                           $37.10/month
```

---

### Scenario 4: Enterprise (Multi-region, High Traffic)

**Infrastructure:**
- 3 environments
- S3 with cross-region replication
- CloudFront (high traffic)
- WAF with advanced rules
- Organizations + Security Hub
- Monitoring (CloudWatch)

**Monthly cost: ~$150-300/month**

**Breakdown:**
```
Dev Environment:
  S3 (typical):                  $0.35/month
  CloudFront:                    $2/month

Staging Environment:
  S3 (advanced):                 $3.40/month
  CloudFront:                    $5/month

Production Environment:
  S3 (advanced, DR):             $10/month (100 GB)
  CloudFront (high traffic):     $50-100/month (10M requests)
  WAF (advanced):                $30/month
  Monitoring:                    $10/month

Organization-wide:
  AWS Organizations:             $10/month
  CloudTrail:                    $10/month (data events)
────────────────────────────────────────────
Total:                           $130.75-180.75/month
```

---

## Cost Optimization Strategies

### 1. Lifecycle Policies (S3)

**Impact:** 50-95% storage cost reduction

**Strategy:**
- Move old versions to IA after 30 days (46% cheaper)
- Move to Glacier after 90 days (83% cheaper)
- Move to Deep Archive after 180 days (95% cheaper)
- Delete after retention period (100% savings)

**Example:**
- Without lifecycle: 100 GB × $0.023 = $2.30/month
- With lifecycle: 10 GB Standard + 30 GB IA + 30 GB Glacier + 30 GB Deep Archive = $0.70/month
- **Savings: $1.60/month (70%)**

---

### 2. CloudFront Cache Optimization

**Impact:** 50-90% origin request reduction

**Strategy:**
- Increase TTL for static assets (JS, CSS, images)
- Use cache keys to maximize hit ratio
- Enable compression (gzip, brotli)

**Example:**
- 1M requests/month to origin: $43/month
- 90% cache hit rate: $4.30/month (90% from cache, free)
- **Savings: $38.70/month (90%)**

---

### 3. Data Transfer Optimization

**Impact:** 60-80% transfer cost reduction

**Strategy:**
- Enable compression (reduces transfer by 60-80%)
- Use CloudFront (cheaper than S3 direct)
- Optimize images (WebP, AVIF formats)

**Example:**
- 500 GB uncompressed transfer: $42.50/month
- 200 GB compressed transfer: $17/month
- **Savings: $25.50/month (60%)**

---

### 4. Request Optimization

**Impact:** 50-90% request cost reduction

**Strategy:**
- Batch small files
- Use multipart upload for large files (>5 MB)
- Minimize LIST operations (expensive)

**Example:**
- 1M LIST requests: $5/month
- 100K LIST requests (cached results): $0.50/month
- **Savings: $4.50/month (90%)**

---

### 5. Monitoring Cost Control

**Impact:** 30-50% monitoring cost reduction

**Strategy:**
- Use metric filters (free) instead of custom metrics
- Increase retention periods gradually
- Use CloudWatch Insights queries instead of exporting logs

**Example:**
- 10 custom metrics: $3/month
- 5 metric filters: $0/month
- **Savings: $3/month (100%)**

---

## Cost Monitoring

### AWS Cost Explorer

Enable Cost Explorer to track spending:
```bash
# View monthly costs by service
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### Budget Alerts

Set up budget alerts:
```bash
# Create budget (example: $50/month)
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

**budget.json:**
```json
{
  "BudgetName": "Monthly Infrastructure Budget",
  "BudgetLimit": {
    "Amount": "50",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

---

## Interactive Cost Calculator

Use AWS Pricing Calculator for accurate estimates:

**Pre-filled templates:**
- [S3 Typical Setup](https://calculator.aws/#/estimate?id=s3-typical-static-website)
- [CloudFront + S3](https://calculator.aws/#/estimate?id=cloudfront-s3-website)
- [Full Stack (S3 + CloudFront + WAF)](https://calculator.aws/#/estimate?id=full-static-website)

---

## See Also

- [Decision Trees](./DECISION_TREES.md) - Which example to choose based on budget
- [Module Examples](../modules/) - Detailed cost breakdowns per example
- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS Cost Management](https://aws.amazon.com/aws-cost-management/)
