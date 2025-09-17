# Variables for GitHub OIDC Provider and Central Role

variable "allowed_repositories" {
  description = "List of GitHub repository patterns allowed to assume this role"
  type        = list(string)
  default = [
    "repo:Celtikill/static-site:environment:*",
    "repo:Celtikill/static-site:ref:refs/heads/main",
    "repo:Celtikill/static-site:ref:refs/heads/feature/*"
  ]
}

variable "target_account_ids" {
  description = "AWS account IDs where deployment roles will be created"
  type        = list(string)
  default = [
    "822529998967", # dev
    "927588814642", # staging
    "546274483801"  # prod
  ]
}

variable "external_id" {
  description = "External ID for additional security when assuming cross-account roles"
  type        = string
  default     = "github-actions-static-site"
  sensitive   = false
}

variable "github_thumbprints" {
  description = "GitHub OIDC provider thumbprints"
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub primary
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  # GitHub backup
  ]
}

variable "session_duration" {
  description = "Maximum session duration for role assumption (in seconds)"
  type        = number
  default     = 3600 # 1 hour
  validation {
    condition     = var.session_duration >= 900 && var.session_duration <= 43200
    error_message = "Session duration must be between 900 seconds (15 minutes) and 43200 seconds (12 hours)."
  }
}