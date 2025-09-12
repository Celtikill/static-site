package terraform.foundation.compliance

# COMPLIANCE POLICIES - These rules WARN but allow deployment

# Rule: Resources should have required tags
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    
    # Only check taggable resource types
    resource.type in [
        "aws_s3_bucket", 
        "aws_organizations_organization",
        "aws_iam_role",
        "aws_cloudfront_distribution"
    ]
    
    required_tags := ["Project", "Environment", "ManagedBy"]
    tags := object.get(resource.values, "tags", {})
    
    required_tag := required_tags[_]
    not tags[required_tag]
    
    msg := sprintf("Resource %s should have required tag: %s", [resource.address, required_tag])
}

# Rule: S3 bucket names should follow naming convention
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    bucket_name := resource.values.bucket
    
    # Expected pattern: project-component-env-suffix
    not regex.match("^[a-z0-9][a-z0-9-]*[a-z0-9]$", bucket_name)
    
    msg := sprintf("S3 bucket '%s' should follow naming convention: lowercase, hyphens allowed, DNS-compliant", [bucket_name])
}

# Rule: IAM roles should have description
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    role_name := resource.values.name
    
    not resource.values.description
    
    msg := sprintf("IAM role '%s' should have a description for documentation", [role_name])
}

# Rule: Organization should have multiple service access principals for comprehensive governance
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_organizations_organization"
    principals := resource.values.aws_service_access_principals
    
    count(principals) < 2
    
    msg := "Organization should enable multiple AWS service access principals for comprehensive governance"
}

# Rule: Resources in production should have additional compliance tags
warn[msg] {
    resource := input.planned_values.root_module.resources[_]
    tags := object.get(resource.values, "tags", {})
    environment := object.get(tags, "Environment", "")
    
    environment == "prod"
    
    # Additional prod tags
    prod_tags := ["CostCenter", "Owner", "DataClassification"]
    prod_tag := prod_tags[_]
    not tags[prod_tag]
    
    msg := sprintf("Production resource %s should have compliance tag: %s", [resource.address, prod_tag])
}