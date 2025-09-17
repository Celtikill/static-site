package terraform.foundation.security

import rego.v1

# SECURITY POLICIES - These rules DENY deployment if violated

# Rule: S3 backends must have encryption enabled
deny contains msg if {
    resource := input.configuration.root_module.resources[_]
    resource.type == "terraform"
    backend := resource.expressions.backend[0]
    backend.s3
    not backend.s3.encrypt.constant_value == true
    
    msg := sprintf("S3 backend for %s must have encryption enabled", [resource.address])
}

# Rule: S3 buckets must have server-side encryption
deny contains msg if {
    resource := input.planned_values.root_module.resources[_] 
    resource.type == "aws_s3_bucket"
    bucket_name := resource.values.bucket
    
    # Check if there's a corresponding encryption configuration
    encryption_exists := count([enc | 
        enc := input.planned_values.root_module.resources[_]
        enc.type == "aws_s3_bucket_server_side_encryption_configuration"
        enc.values.bucket == bucket_name
    ]) > 0
    
    not encryption_exists
    
    msg := sprintf("S3 bucket '%s' must have server-side encryption configured", [bucket_name])
}

# Rule: AWS Organizations must have CloudTrail service access
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    principals := resource.values.aws_service_access_principals
    
    not "cloudtrail.amazonaws.com" in principals
    
    msg := "AWS Organizations must have CloudTrail service access enabled"
}

# Rule: AWS Organizations must have Config service access  
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    principals := resource.values.aws_service_access_principals
    
    not "config.amazonaws.com" in principals
    
    msg := "AWS Organizations must have Config service access enabled"
}

# Rule: Organizations must have Service Control Policies enabled
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    policy_types := resource.values.enabled_policy_types
    
    not "SERVICE_CONTROL_POLICY" in policy_types
    
    msg := "AWS Organizations must have Service Control Policies enabled"
}

# Rule: IAM roles should use data sources, not create new ones (except for specific cases)
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    role_name := resource.values.name

    # Allow S3 replication role as exception
    not role_name == "static-site-s3-replication"

    msg := sprintf("IAM role '%s' should use data sources instead of creating new roles (security best practice)", [role_name])
}

# Rule: Terraform modules must use proper provider configuration
deny contains msg if {
    # Check if configuration has modules that reference providers
    some module_key
    module_config := input.configuration.root_module.module_calls[module_key]

    # If module has provider requirements in required_providers, it should not define its own providers
    module_path := module_config.source

    # This is a configuration-level check - modules should use configuration_aliases not provider blocks
    msg := sprintf("Module '%s' should use configuration_aliases instead of defining provider blocks (2025 best practice)", [module_key])
}

# Rule: Provider configuration must be consistent across environments
deny contains msg if {
    # Check for provider configurations that should be standardized
    provider_config := input.configuration.root_module.provider_configs[_]
    provider_name := provider_config.name

    # AWS provider must specify region consistently
    provider_name == "aws"
    not provider_config.expressions.region

    msg := sprintf("AWS provider configuration must specify region explicitly for consistency", [])
}