<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Cost Projection - ${environment} | ${project}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f7fa;
            color: #2d3748;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5rem;
            font-weight: 300;
        }
        .subtitle {
            margin-top: 10px;
            opacity: 0.9;
            font-size: 1.1rem;
        }
        .content {
            padding: 30px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #f8fafc;
            padding: 25px;
            border-radius: 8px;
            border-left: 4px solid #4299e1;
            transition: transform 0.2s;
        }
        .metric-card:hover {
            transform: translateY(-2px);
        }
        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            color: #2b6cb0;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #718096;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .status-badge {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 0.9rem;
            margin: 20px 0;
        }
        .status-healthy {
            background: #c6f6d5;
            color: #22543d;
        }
        .status-warning {
            background: #fef5e7;
            color: #c05621;
        }
        .status-critical {
            background: #fed7d7;
            color: #c53030;
        }
        .table-container {
            overflow-x: auto;
            margin: 20px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
        }
        th {
            background: #f7fafc;
            font-weight: 600;
            color: #2d3748;
        }
        .service-bar {
            display: flex;
            align-items: center;
            margin: 5px 0;
        }
        .service-name {
            min-width: 120px;
            font-weight: 500;
        }
        .bar-container {
            flex: 1;
            height: 20px;
            background: #edf2f7;
            border-radius: 10px;
            margin: 0 10px;
            overflow: hidden;
        }
        .bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #4299e1, #667eea);
            border-radius: 10px;
            transition: width 0.5s ease;
        }
        .percentage {
            min-width: 50px;
            text-align: right;
            font-weight: 600;
            color: #4a5568;
        }
        .recommendations {
            background: #edf2f7;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .recommendations h3 {
            color: #2d3748;
            margin-top: 0;
        }
        .recommendation-item {
            display: flex;
            align-items: flex-start;
            margin: 10px 0;
            padding: 10px;
            background: white;
            border-radius: 6px;
            border-left: 3px solid #4299e1;
        }
        .recommendation-icon {
            margin-right: 10px;
            font-size: 1.2rem;
        }
        .footer {
            background: #f8fafc;
            padding: 20px;
            text-align: center;
            color: #718096;
            font-size: 0.9rem;
            border-top: 1px solid #e2e8f0;
        }
        .progress-ring {
            transform: rotate(-90deg);
        }
        .progress-ring-circle {
            fill: transparent;
            stroke: #e2e8f0;
            stroke-width: 4;
        }
        .progress-ring-fill {
            fill: transparent;
            stroke: #4299e1;
            stroke-width: 4;
            stroke-linecap: round;
            stroke-dasharray: ${format("%.2f", budget_utilization * 251.2 / 100)} 251.2;
            transition: stroke-dasharray 0.5s ease;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>💰 AWS Cost Projection</h1>
            <div class="subtitle">
                ${environment} Environment | ${region} | ${project}<br>
                Generated: ${timestamp}
            </div>
        </div>

        <div class="content">
            <div class="metrics-grid">
                <div class="metric-card">
                    <div class="metric-value">$${format("%.2f", total_monthly)}</div>
                    <div class="metric-label">Monthly Cost</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">$${format("%.2f", total_annual)}</div>
                    <div class="metric-label">Annual Projection</div>
                </div>
                %{if budget_limit > 0}
                <div class="metric-card">
                    <div class="metric-value">$${format("%.2f", budget_limit)}</div>
                    <div class="metric-label">Budget Limit</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">${format("%.1f", budget_utilization)}%</div>
                    <div class="metric-label">Budget Utilization</div>
                </div>
                %{endif}
            </div>

            %{if budget_limit > 0}
            <div style="text-align: center;">
                %{if budget_critical}
                <div class="status-badge status-critical">🔴 CRITICAL: Cost exceeds budget!</div>
                %{else}%{if budget_warning}
                <div class="status-badge status-warning">🟡 WARNING: Approaching budget limit</div>
                %{else}
                <div class="status-badge status-healthy">🟢 HEALTHY: Within budget</div>
                %{endif}%{endif}
            </div>
            %{endif}

            <h2>🔧 Service Cost Breakdown</h2>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Service</th>
                            <th>Monthly Cost</th>
                            <th>Distribution</th>
                            <th>Percentage</th>
                        </tr>
                    </thead>
                    <tbody>
                        %{for service, cost in service_costs}
                        <tr>
                            <td><strong>${title(service)}</strong></td>
                            <td>$${format("%.2f", cost)}</td>
                            <td>
                                <div class="bar-container">
                                    <div class="bar-fill" style="width: ${service_percentages[service]}%"></div>
                                </div>
                            </td>
                            <td>${format("%.1f", service_percentages[service])}%</td>
                        </tr>
                        %{endfor}
                    </tbody>
                </table>
            </div>

            <h2>📈 Resource Usage Details</h2>
            <div class="table-container">
                <table>
                    <tbody>
                        <tr><td><strong>S3 Storage</strong></td><td>${resource_details.s3_storage_gb} GB</td></tr>
                        <tr><td><strong>CloudFront Data Transfer</strong></td><td>${resource_details.cloudfront_data_gb} GB</td></tr>
                        <tr><td><strong>HTTPS Requests</strong></td><td>${format("%.0f", resource_details.cloudfront_requests)}</td></tr>
                        <tr><td><strong>WAF Protection</strong></td><td>${resource_details.waf_enabled ? "✅ Enabled" : "❌ Disabled"}</td></tr>
                        <tr><td><strong>Route53 DNS</strong></td><td>${resource_details.route53_enabled ? "✅ Enabled" : "❌ Disabled"}</td></tr>
                        <tr><td><strong>KMS Encryption</strong></td><td>${resource_details.kms_enabled ? "✅ Enabled" : "❌ Disabled"}</td></tr>
                        <tr><td><strong>Cross-Region Replication</strong></td><td>${resource_details.cross_region_repl ? "✅ Enabled" : "❌ Disabled"}</td></tr>
                        <tr><td><strong>Environment Multiplier</strong></td><td>${resource_details.environment_multiplier}x</td></tr>
                    </tbody>
                </table>
            </div>

            <div class="recommendations">
                <h3>🎯 Cost Optimization Recommendations</h3>
                %{if total_monthly > 100}
                <div class="recommendation-item">
                    <div class="recommendation-icon">💡</div>
                    <div>Consider Reserved Instances for predictable workloads to reduce costs by 30-60%</div>
                </div>
                %{endif}
                %{if !resource_details.cross_region_repl && environment == "prod"}
                <div class="recommendation-item">
                    <div class="recommendation-icon">🛡️</div>
                    <div>Enable cross-region replication for disaster recovery in production</div>
                </div>
                %{endif}
                %{if service_costs.cloudfront > service_costs.s3 * 3}
                <div class="recommendation-item">
                    <div class="recommendation-icon">⚡</div>
                    <div>Review CloudFront caching settings to optimize data transfer costs</div>
                </div>
                %{endif}
                %{if budget_limit > 0 && budget_utilization > 80}
                <div class="recommendation-item">
                    <div class="recommendation-icon">⚠️</div>
                    <div>Budget utilization high - consider cost optimization measures</div>
                </div>
                %{endif}
                %{if environment == "dev"}
                <div class="recommendation-item">
                    <div class="recommendation-icon">⏰</div>
                    <div>Development environment - consider scheduled shutdown during non-business hours</div>
                </div>
                %{endif}
            </div>
        </div>

        <div class="footer">
            Report generated by Cost Projection Module v1.0<br>
            Pricing based on AWS us-east-1 region as of 2024
        </div>
    </div>
</body>
</html>