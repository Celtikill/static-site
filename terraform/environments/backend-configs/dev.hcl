# Development Environment Backend Configuration
# AWS Best Practice: Separate backend per environment in respective account

bucket         = "static-website-state-dev-822529998967"
key            = "environments/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "static-website-locks-dev"
encrypt        = true

# Account: 822529998967 (Dev)