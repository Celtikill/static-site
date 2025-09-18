# Development Environment Backend Configuration
# Project: static-site
# AWS Best Practice: Separate backend per environment in respective account

bucket         = "static-site-state-dev-822529998967"
key            = "environments/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "static-site-locks-dev"
encrypt        = true

# Account: 822529998967 (Dev)
# Project: static-site (follows {project}-state-{env}-{account} pattern)