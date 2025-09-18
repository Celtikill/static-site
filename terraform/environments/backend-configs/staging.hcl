# Staging Environment Backend Configuration
# AWS Best Practice: Separate backend per environment in respective account

bucket         = "static-website-state-staging-927588814642"
key            = "environments/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "static-website-locks-staging"
encrypt        = true

# Account: 927588814642 (Staging)