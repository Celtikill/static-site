# AWS Organizations Module Variables

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy    = "terraform"
    Module       = "aws-organizations"
    Architecture = "sra-aligned"
  }
}