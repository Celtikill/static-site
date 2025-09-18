# Production Environment Backend Configuration
# AWS Best Practice: Separate backend per environment in respective account

bucket         = "static-website-state-prod-546274483801"
key            = "environments/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "static-website-locks-prod"
encrypt        = true

# Account: 546274483801 (Prod)