# Cost Projection Module Outputs
# Provides cost data in multiple formats for CI/CD integration and reporting

# Raw cost data outputs
output "monthly_cost_total" {
  description = "Total monthly cost in USD"
  value       = local.total_monthly_cost
}

output "annual_cost_total" {
  description = "Total annual cost projection in USD"
  value       = local.total_annual_cost
}

output "service_costs" {
  description = "Monthly cost breakdown by AWS service"
  value       = local.service_costs
}

output "budget_utilization_percent" {
  description = "Budget utilization as percentage"
  value       = local.cost_breakdown.budget_utilization
}

# Cost breakdown with metadata
output "cost_breakdown" {
  description = "Complete cost breakdown with metadata"
  value       = local.cost_breakdown
}

# JSON format for programmatic access
output "cost_report_json" {
  description = "Cost report in JSON format"
  value = jsonencode({
    report_metadata = {
      generated_at  = local.cost_breakdown.timestamp
      environment   = var.environment
      region        = var.aws_region
      project       = var.project_name
      account_type  = var.account_type
    }
    
    cost_summary = {
      total_monthly_usd = local.total_monthly_cost
      total_annual_usd  = local.total_annual_cost
      currency         = "USD"
      budget_limit     = var.monthly_budget_limit
      budget_utilization = local.cost_breakdown.budget_utilization
      
      # Cost status indicators
      status = {
        within_budget = var.monthly_budget_limit > 0 ? local.total_monthly_cost <= var.monthly_budget_limit : true
        budget_warning = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 80 : false
        budget_critical = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 100 : false
      }
    }
    
    service_breakdown = {
      costs = local.service_costs
      percentages = local.cost_breakdown.service_percentages
    }
    
    resource_details = local.cost_breakdown.resource_details
    
    recommendations = var.enable_cost_optimization_analysis ? [
      local.total_monthly_cost > 100 ? "Consider Reserved Instances for predictable workloads" : null,
      !var.enable_cross_region_replication && var.environment == "prod" ? "Enable cross-region replication for disaster recovery" : null,
      local.service_costs.cloudfront > local.service_costs.s3 * 3 ? "Review CloudFront caching settings to optimize data transfer costs" : null,
      var.monthly_budget_limit > 0 && local.cost_breakdown.budget_utilization > 80 ? "Budget utilization high - consider cost optimization" : null
    ] : []
  })
}

# Markdown format for GitHub comments and documentation
output "cost_report_markdown" {
  description = "Cost report in Markdown format"
  value = templatefile("${path.module}/templates/cost-report.md.tpl", {
    environment = var.environment
    region = var.aws_region
    project = var.project_name
    timestamp = local.cost_breakdown.timestamp
    
    total_monthly = local.total_monthly_cost
    total_annual = local.total_annual_cost
    budget_limit = var.monthly_budget_limit
    budget_utilization = local.cost_breakdown.budget_utilization
    
    service_costs = local.service_costs
    service_percentages = local.cost_breakdown.service_percentages
    resource_details = local.cost_breakdown.resource_details
    
    within_budget = var.monthly_budget_limit > 0 ? local.total_monthly_cost <= var.monthly_budget_limit : true
    budget_warning = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 80 : false
    budget_critical = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 100 : false
  })
}

# HTML format for web dashboards
output "cost_report_html" {
  description = "Cost report in HTML format"
  value = templatefile("${path.module}/templates/cost-report.html.tpl", {
    environment = var.environment
    region = var.aws_region
    project = var.project_name
    timestamp = local.cost_breakdown.timestamp
    
    total_monthly = local.total_monthly_cost
    total_annual = local.total_annual_cost
    budget_limit = var.monthly_budget_limit
    budget_utilization = local.cost_breakdown.budget_utilization
    
    service_costs = local.service_costs
    service_percentages = local.cost_breakdown.service_percentages
    resource_details = local.cost_breakdown.resource_details
    
    within_budget = var.monthly_budget_limit > 0 ? local.total_monthly_cost <= var.monthly_budget_limit : true
    budget_warning = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 80 : false
    budget_critical = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 100 : false
  })
}

# CSV format for spreadsheet analysis
output "cost_report_csv" {
  description = "Cost report in CSV format"
  value = join("\n", concat(
    ["Service,Monthly_Cost_USD,Percentage,Environment,Region"],
    [for service, cost in local.service_costs : 
      "${service},${cost},${local.cost_breakdown.service_percentages[service]},${var.environment},${var.aws_region}"
    ],
    ["TOTAL,${local.total_monthly_cost},100.0,${var.environment},${var.aws_region}"]
  ))
}

# Budget validation outputs for CI/CD
output "budget_validation" {
  description = "Budget validation results for CI/CD pipeline"
  value = {
    within_budget = var.monthly_budget_limit > 0 ? local.total_monthly_cost <= var.monthly_budget_limit : true
    budget_warning = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 80 : false
    budget_critical = var.monthly_budget_limit > 0 ? local.cost_breakdown.budget_utilization >= 100 : false
    
    monthly_cost = local.total_monthly_cost
    budget_limit = var.monthly_budget_limit
    utilization_percent = local.cost_breakdown.budget_utilization
    
    # Exit codes for CI/CD
    exit_code = var.monthly_budget_limit > 0 ? (
      local.cost_breakdown.budget_utilization >= 100 ? 2 : (  # Critical: fail deployment
        local.cost_breakdown.budget_utilization >= 80 ? 1 : 0  # Warning: allow but warn
      )
    ) : 0
  }
}

# Cost comparison outputs (for environment comparison)
output "cost_comparison_baseline" {
  description = "Baseline cost data for environment comparison"
  value = {
    environment = var.environment
    monthly_cost = local.total_monthly_cost
    services = local.service_costs
    resource_usage = local.cost_breakdown.resource_details
    timestamp = local.cost_breakdown.timestamp
  }
}

# CloudWatch metrics outputs
output "cloudwatch_metrics" {
  description = "Cost metrics for CloudWatch integration"
  value = {
    monthly_cost = {
      metric_name = "MonthlyCostProjection"
      value = local.total_monthly_cost
      unit = "None"
      dimensions = {
        Environment = var.environment
        Project = var.project_name
        Region = var.aws_region
      }
    }
    
    budget_utilization = {
      metric_name = "BudgetUtilization"
      value = local.cost_breakdown.budget_utilization
      unit = "Percent"
      dimensions = {
        Environment = var.environment
        Project = var.project_name
        Region = var.aws_region
      }
    }
    
    service_costs = [
      for service, cost in local.service_costs : {
        metric_name = "ServiceCost"
        value = cost
        unit = "None"
        dimensions = {
          Environment = var.environment
          Project = var.project_name
          Service = service
          Region = var.aws_region
        }
      }
    ]
  }
}

# Alert configuration outputs
output "cost_alerts" {
  description = "Cost alert thresholds and configurations"
  value = var.monthly_budget_limit > 0 ? {
    budget_alerts = [
      {
        threshold_percent = 80
        threshold_amount = var.monthly_budget_limit * 0.8
        alert_type = "warning"
        message = "Cost projection at 80% of budget limit"
      },
      {
        threshold_percent = 100
        threshold_amount = var.monthly_budget_limit
        alert_type = "critical"
        message = "Cost projection exceeds budget limit"
      }
    ]
    
    service_alerts = [
      for service, cost in local.service_costs : {
        service = service
        cost = cost
        alert_if_exceeds = var.monthly_budget_limit * 0.5  # Alert if any service exceeds 50% of budget
        requires_attention = cost > var.monthly_budget_limit * 0.5
      } if cost > var.monthly_budget_limit * 0.5
    ]
  } : null
}

# Multi-account cost aggregation support
output "account_cost_summary" {
  description = "Cost summary for multi-account aggregation"
  value = {
    account_type = var.account_type
    environment = var.environment
    region = var.aws_region
    monthly_cost = local.total_monthly_cost
    annual_cost = local.total_annual_cost
    service_breakdown = local.service_costs
    
    # Account-specific cost categories
    infrastructure_cost = local.service_costs.s3 + local.service_costs.cloudfront + local.service_costs.route53
    security_cost = local.service_costs.waf + local.service_costs.kms
    monitoring_cost = local.service_costs.cloudwatch + local.service_costs.sns
    
    last_calculated = local.cost_breakdown.timestamp
  }
}