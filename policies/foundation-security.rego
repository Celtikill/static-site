package terraform.foundation.security

# SECURITY POLICIES - These rules DENY deployment if violated

# Rule: S3 backends must have encryption enabled
deny[msg] {
    resource := input.configuration.root_module.resources[_]
    resource.type == "terraform"
    backend := resource.expressions.backend[0]
    backend.s3
    not backend.s3.encrypt.constant_value == true
    
    msg := sprintf("S3 backend for %s must have encryption enabled", [resource.address])
}

# Rule: S3 buckets must have server-side encryption
deny[msg] {
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
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    principals := resource.values.aws_service_access_principals
    
    not "cloudtrail.amazonaws.com" in principals
    
    msg := "AWS Organizations must have CloudTrail service access enabled"
}

# Rule: AWS Organizations must have Config service access  
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    principals := resource.values.aws_service_access_principals
    
    not "config.amazonaws.com" in principals
    
    msg := "AWS Organizations must have Config service access enabled"
}

# Rule: Organizations must have Service Control Policies enabled
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    policy_types := resource.values.enabled_policy_types
    
    not "SERVICE_CONTROL_POLICY" in policy_types
    
    msg := "AWS Organizations must have Service Control Policies enabled"
}

# Rule: IAM roles should use data sources, not create new ones (except for specific cases)
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    role_name := resource.values.name
    
    # Allow S3 replication role as exception
    not role_name == "static-site-s3-replication"
    
    msg := sprintf("IAM role '%s' should use data sources instead of creating new roles (security best practice)", [role_name])
}