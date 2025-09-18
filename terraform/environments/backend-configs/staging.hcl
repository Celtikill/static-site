# Staging Environment Backend Configuration
# Project: static-site
# AWS Best Practice: Separate backend per environment in respective account

bucket         = "static-site-state-staging-927588814642"
key            = "environments/staging/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "static-site-locks-staging"
encrypt        = true

# Account: 927588814642 (Staging)
# Project: static-site (follows {project}-state-{env}-{account} pattern)