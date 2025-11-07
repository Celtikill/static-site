# Example IAM Policy Files

This directory contains example IAM policy files that demonstrate the structure and format for various AWS IAM policies used in this project.

## Important: Replace Placeholder Values

Files with `.example` extension contain placeholder values that **MUST** be replaced with your actual values:

### github-oidc-trust-policy.json.example

This file contains an example OIDC trust policy for GitHub Actions. Before using it, replace:

- `223938610551` → Your AWS account ID where the OIDC provider is created
- `Celtikill/static-site` → Your GitHub repository in the format `OWNER/REPO`

Example replacements:
```json
// Replace this:
"Federated": "arn:aws:iam::223938610551:oidc-provider/token.actions.githubusercontent.com"
// With:
"Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"

// Replace this:
"repo:Celtikill/static-site:ref:refs/heads/main"
// With:
"repo:YOUR_OWNER/YOUR_REPO:ref:refs/heads/main"
```

## Using the Bootstrap Scripts

The bootstrap scripts automatically generate policies from templates with the correct values. You don't need to manually edit these example files unless you're creating custom policies.

The templates used by bootstrap scripts are located in:
- `/policies/*.json.tpl` - Template files with placeholders
- These templates are processed by `scripts/bootstrap/lib/policies.sh`

## Note for Forks

If you've forked this repository:
1. Update the values in `scripts/config.sh`
2. Set GitHub repository variables (Settings → Secrets and Variables → Actions → Variables)
3. Run the bootstrap scripts which will generate policies with your values