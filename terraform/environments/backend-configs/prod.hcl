# Production Environment Backend Configuration
# Project: static-site
# AWS Best Practice: Separate backend per environment in respective account

bucket         = "static-site-state-prod-546274483801"
key            = "environments/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "static-site-locks-prod"
encrypt        = true

# Account: 546274483801 (Prod)
# Project: static-site (follows {project}-state-{env}-{account} pattern)