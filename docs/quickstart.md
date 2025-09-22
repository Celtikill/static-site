# 10-Minute Quickstart

Deploy a secure static website to AWS in under 10 minutes.

## Prerequisites (2 min)

Ensure you have:
- ✅ AWS account with admin access
- ✅ GitHub account
- ✅ GitHub CLI installed (`gh --version`)

## Step 1: Fork & Clone (1 min)

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/static-site.git
cd static-site
```

## Step 2: Configure AWS Access (3 min)

### Option A: Quick Setup (Recommended)
Use the provided CloudFormation template:

```bash
# Deploy IAM roles to your AWS account
aws cloudformation create-stack \
  --stack-name static-site-roles \
  --template-body file://iam/cloudformation/oidc-roles.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=GitHubOrg,ParameterValue=YOUR_GITHUB_ORG

# Wait for completion (2-3 minutes)
aws cloudformation wait stack-create-complete \
  --stack-name static-site-roles
```

### Option B: Manual Setup
Create the central role manually in AWS Console:
1. Go to IAM → Roles → Create Role
2. Choose "Web identity" → GitHub as provider
3. Add your repository to the trust policy
4. Attach necessary permissions

## Step 3: Set GitHub Secret (1 min)

```bash
# Get the role ARN from CloudFormation
ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name static-site-roles \
  --query 'Stacks[0].Outputs[?OutputKey==`CentralRoleArn`].OutputValue' \
  --output text)

# Set the GitHub secret
gh secret set AWS_ASSUME_ROLE_CENTRAL --body "$ROLE_ARN"
```

## Step 4: Deploy! (3 min)

```bash
# Push to trigger automatic deployment
git checkout -b feature/first-deploy
git commit --allow-empty -m "Initial deployment"
git push origin feature/first-deploy
```

This triggers the automated pipeline:
- **BUILD** (20s): Security scanning
- **TEST** (40s): Policy validation
- **RUN** (2min): Infrastructure deployment

## Step 5: View Your Site (instant)

```bash
# Get the website URL
gh run view --log | grep "Website URL"

# Or check the GitHub Actions summary
gh run view --web
```

Your site is now live! 🎉

## What You Just Deployed

✅ S3 bucket for website hosting
✅ CloudFront CDN (optional)
✅ WAF protection (optional)
✅ Automated CI/CD pipeline
✅ Security scanning
✅ Cost monitoring

## Next Steps

- **[Enable CloudFront](feature-flags.md)** - Add CDN for better performance
- **[Configure Custom Domain](../terraform/README.md)** - Use your own domain
- **[Set Up Monitoring](workflows.md#monitoring)** - Track costs and performance

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Role not found" | Check CloudFormation stack completed |
| "Access denied" | Verify GitHub secret is set correctly |
| "Build failed" | Check [troubleshooting guide](troubleshooting.md) |

---

**Need help?** [Open an issue](https://github.com/celtikill/static-site/issues) | [Full Documentation](index.md)