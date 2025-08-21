# OIDC Security Hardening Guide

[![Security](https://img.shields.io/badge/Security-Hardened-green)](https://github.com/OWASP/ASVS)
[![Compliance](https://img.shields.io/badge/Compliance-ASVS%20L2-blue)](https://github.com/OWASP/ASVS)

Advanced security hardening techniques for GitHub Actions OIDC authentication to achieve enterprise-grade security posture.

## 🎯 Security Objectives

- **Zero Trust**: Never trust, always verify
- **Least Privilege**: Minimal necessary permissions
- **Defense in Depth**: Multiple security layers
- **Audit Trail**: Complete access logging
- **Incident Response**: Rapid threat detection

## 🔒 Advanced Trust Policy Hardening

### 1. Repository-Specific Scoping

#### Basic Trust Policy (❌ Less Secure)
```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:*:*"
  }
}
```

#### Hardened Trust Policy (✅ Secure)
```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:repository": "celtikill/static-site"
  },
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:celtikill/static-site:ref:refs/heads/main"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:repository_owner": "celtikill"
  }
}
```

### 2. Workflow-Specific Access Control

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:job_workflow_ref": [
        "celtikill/static-site/.github/workflows/deploy.yml@refs/heads/main"
      ]
    }
  }
}
```

### 3. Environment-Based Restrictions

```json
{
  "Condition": {
    "ForAllValues:StringEquals": {
      "token.actions.githubusercontent.com:environment": [
        "production",
        "staging"
      ]
    }
  }
}
```

### 4. Time-Based Access Control

```json
{
  "Condition": {
    "DateGreaterThan": {
      "aws:TokenIssueTime": "2024-01-01T00:00:00Z"
    },
    "NumericLessThan": {
      "aws:TokenAge": "3600"
    }
  }
}
```

## 🛡️ IAM Permission Hardening

### 1. Resource-Specific Permissions

#### Standard Permissions (❌ Broad)
```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}
```

#### Hardened Permissions (✅ Specific)
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ],
  "Resource": [
    "arn:aws:s3:::static-site-${aws:PrincipalTag/Environment}/*"
  ],
  "Condition": {
    "StringEquals": {
      "s3:ExistingObjectTag/Project": "static-site"
    }
  }
}
```

### 2. Tag-Based Access Control

```json
{
  "Effect": "Allow",
  "Action": [
    "cloudfront:CreateInvalidation",
    "cloudfront:GetDistribution"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "cloudfront:DistributionTag/Project": "static-site",
      "cloudfront:DistributionTag/Environment": "${aws:PrincipalTag/Environment}"
    }
  }
}
```

### 3. IP Address Restrictions

```json
{
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": [
        "192.30.252.0/22",
        "185.199.108.0/22",
        "140.82.112.0/20",
        "143.55.64.0/20"
      ]
    }
  }
}
```

## 📊 Advanced Monitoring

### 1. CloudTrail Event Monitoring

#### Critical Events to Monitor
```json
{
  "eventName": [
    "AssumeRoleWithWebIdentity",
    "CreateRole",
    "DeleteRole",
    "PutRolePolicy",
    "AttachRolePolicy",
    "DetachRolePolicy"
  ]
}
```

#### CloudWatch Log Insights Query
```sql
fields @timestamp, userIdentity.type, eventName, sourceIPAddress, userAgent
| filter eventName = "AssumeRoleWithWebIdentity"
| filter userIdentity.principalId like /github-actions/
| stats count() by sourceIPAddress
| sort @timestamp desc
```

### 2. Custom CloudWatch Metrics

```python
import boto3
import json

def lambda_handler(event, context):
    """Monitor OIDC authentication events"""
    
    cloudwatch = boto3.client('cloudwatch')
    
    # Extract CloudTrail event
    detail = event['detail']
    
    if detail['eventName'] == 'AssumeRoleWithWebIdentity':
        # Extract repository from token
        web_identity_token = detail['requestParameters']['webIdentityToken']
        
        # Put custom metric
        cloudwatch.put_metric_data(
            Namespace='GitHub/OIDC',
            MetricData=[
                {
                    'MetricName': 'RoleAssumptions',
                    'Dimensions': [
                        {
                            'Name': 'Repository',
                            'Value': extract_repository(web_identity_token)
                        }
                    ],
                    'Value': 1,
                    'Unit': 'Count'
                }
            ]
        )
```

### 3. Real-Time Alerts

```yaml
# CloudFormation template for security alerts
UnauthorizedOIDCAccess:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: OIDC-UnauthorizedAccess
    AlarmDescription: Unauthorized OIDC role assumption attempt
    MetricName: ErrorCount
    Namespace: AWS/CloudTrail
    Statistic: Sum
    Period: 300
    EvaluationPeriods: 1
    Threshold: 1
    ComparisonOperator: GreaterThanOrEqualToThreshold
    AlarmActions:
      - !Ref SecurityIncidentTopic
```

## 🔐 Network Security

### 1. VPC Endpoints for AWS Services

```hcl
# Terraform configuration for VPC endpoints
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "sts:AssumeRoleWithWebIdentity",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.github_repository
          }
        }
      }
    ]
  })
}
```

### 2. WAF Rules for GitHub IPs

```json
{
  "Name": "GitHubActionsIPRestriction",
  "Priority": 1,
  "Statement": {
    "IPSetReferenceStatement": {
      "ARN": "arn:aws:wafv2:us-east-1:123456789012:global/ipset/github-actions-ips/a1b2c3d4"
    }
  },
  "Action": {
    "Allow": {}
  }
}
```

## 🔄 Incident Response

### 1. Automated Response Playbook

```python
def handle_security_incident(event):
    """Automated response to OIDC security incidents"""
    
    incident_type = event['detail']['eventName']
    
    if incident_type == 'AssumeRoleWithWebIdentity':
        source_ip = event['detail']['sourceIPAddress']
        
        # Check if IP is from GitHub Actions
        if not is_github_actions_ip(source_ip):
            # Immediate response actions
            disable_oidc_provider()
            send_security_alert()
            create_incident_ticket()
            
    return {
        'statusCode': 200,
        'body': json.dumps('Incident handled')
    }
```

### 2. Forensic Data Collection

```bash
#!/bin/bash
# OIDC forensic data collection script

# Collect CloudTrail events
aws logs filter-log-events \
  --log-group-name CloudTrail \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern '{ $.eventName = "AssumeRoleWithWebIdentity" }' \
  --output json > oidc_events.json

# Collect IAM role details
aws iam get-role --role-name github-actions-static-site > role_details.json

# Collect OIDC provider configuration
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com \
  > oidc_provider.json
```

### 3. Recovery Procedures

```yaml
# Emergency OIDC provider recreation
- name: Emergency OIDC Recovery
  run: |
    # Backup current configuration
    aws iam get-open-id-connect-provider \
      --open-id-connect-provider-arn $PROVIDER_ARN \
      > oidc_backup_$(date +%s).json
    
    # Remove compromised provider
    aws iam delete-open-id-connect-provider \
      --open-id-connect-provider-arn $PROVIDER_ARN
    
    # Recreate with updated thumbprint
    aws iam create-open-id-connect-provider \
      --url https://token.actions.githubusercontent.com \
      --thumbprint-list $NEW_THUMBPRINT \
      --client-id-list sts.amazonaws.com
```

## 🎯 Compliance Mapping

### ASVS v4.0 Level 2 Requirements

| Requirement | Implementation | Evidence |
|-------------|---------------|----------|
| 2.1.1 - Password Security | No passwords used - OIDC only | ✅ Trust policy verification |
| 2.2.1 - General Authenticator | GitHub OIDC provider | ✅ Provider configuration |
| 2.7.1 - Session Management | Unique session per workflow | ✅ CloudTrail session tracking |
| 2.8.1 - Single Sign-On | GitHub SSO integration | ✅ OIDC token validation |
| 3.1.1 - Session Binding | Token bound to repository | ✅ Trust policy conditions |

### SOC 2 Type II Controls

| Control | Implementation | Monitoring |
|---------|---------------|------------|
| CC6.1 - Logical Access | IAM role-based access | CloudTrail logging |
| CC6.2 - Authentication | OIDC token validation | STS event monitoring |
| CC6.3 - Authorization | Least privilege policies | Policy compliance scanning |
| CC6.7 - System Boundaries | Network restrictions | VPC flow logs |
| CC6.8 - Vulnerability Management | Automated security scanning | Security findings tracking |

## 🔧 Security Testing

### 1. Penetration Testing Checklist

```bash
# Test token manipulation
curl -X POST https://sts.amazonaws.com/ \
  -H "Content-Type: application/x-amz-json-1.1" \
  -d '{
    "Action": "AssumeRoleWithWebIdentity",
    "WebIdentityToken": "MANIPULATED_TOKEN",
    "RoleArn": "arn:aws:iam::123456789012:role/github-actions-static-site"
  }'

# Test IP address bypass
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::123456789012:role/github-actions-static-site \
  --role-session-name test \
  --web-identity-token $OIDC_TOKEN \
  --endpoint-url https://sts.amazonaws.com
```

### 2. Continuous Security Validation

```yaml
# GitHub Action for security testing
name: OIDC Security Validation
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

jobs:
  security-test:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Test OIDC Token Properties
        run: |
          # Decode and validate token claims
          echo $ACTIONS_ID_TOKEN_REQUEST_TOKEN | base64 -d | jq .
          
          # Verify token expiration
          CURRENT_TIME=$(date +%s)
          TOKEN_EXP=$(echo $TOKEN | jq -r '.exp')
          
          if [ $TOKEN_EXP -lt $CURRENT_TIME ]; then
            echo "❌ Token expired"
            exit 1
          fi
```

## 📈 Security Metrics

### Key Performance Indicators

1. **Mean Time to Detect (MTTD)**: < 5 minutes
2. **Mean Time to Respond (MTTR)**: < 15 minutes
3. **False Positive Rate**: < 2%
4. **Authentication Success Rate**: > 99.9%
5. **Policy Compliance Score**: 100%

### Monitoring Dashboard

```python
# CloudWatch dashboard configuration
dashboard_body = {
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["GitHub/OIDC", "RoleAssumptions", "Repository", "celtikill/static-site"],
                    ["AWS/CloudTrail", "ErrorCount", "EventName", "AssumeRoleWithWebIdentity"]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "OIDC Authentication Metrics"
            }
        }
    ]
}
```

## 🚨 Security Checklist

### Pre-Deployment Security Review

- [ ] ✅ Trust policy restricts to specific repository
- [ ] ✅ Trust policy restricts to specific branches
- [ ] ✅ IAM permissions follow least privilege
- [ ] ✅ Resource restrictions use tags/conditions
- [ ] ✅ CloudTrail logging enabled
- [ ] ✅ CloudWatch monitoring configured
- [ ] ✅ Security alerts configured
- [ ] ✅ Incident response procedures documented
- [ ] ✅ Regular security testing scheduled
- [ ] ✅ Compliance requirements validated

### Runtime Security Monitoring

- [ ] ✅ Failed authentication attempts < threshold
- [ ] ✅ All role assumptions from expected IPs
- [ ] ✅ Token expiration times within limits
- [ ] ✅ No privilege escalation attempts
- [ ] ✅ Resource access patterns normal
- [ ] ✅ CloudTrail events complete and intact
- [ ] ✅ Security alerts functioning
- [ ] ✅ Backup and recovery procedures tested

---

**🔐 Security is a journey, not a destination.** Regular reviews, testing, and updates ensure your OIDC implementation remains secure against evolving threats.