# AWS Static Website Architecture Demo

A comprehensive demonstration of AWS Well-Architected Framework principles through a serverless static website deployment. This project showcases modern cloud architecture patterns, security best practices, and cost optimization strategies.

## 🏗️ Architecture Overview

This project implements a multi-tier serverless architecture featuring:

- **Content Delivery**: S3 static hosting with CloudFront global CDN
- **Security**: AWS WAF, SSL/TLS termination, and security headers
- **Reliability**: Multi-region replication with automated failover
- **Performance**: Global edge caching with <100ms latency targets
- **Cost Optimization**: Intelligent tiering and automated cost controls
- **Operations**: Fully automated CI/CD with GitHub Actions

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- OpenTofu (open-source Terraform alternative) installed
- GitHub account with Actions enabled
- Domain name for SSL certificate (optional)

## 🚀 Quick Start

1. **Clone and Initialize**
   ```bash
   git clone <repository-url>
   cd static-site
   tofu init
   ```

2. **Configure Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Deploy Infrastructure**
   ```bash
   tofu plan
   tofu apply
   ```

4. **Deploy Website**
   ```bash
   # GitHub Actions will automatically deploy on push to main branch
   git push origin main
   ```

## 📁 Project Structure

```
static-site/
├── ARCHITECTURE.md          # Detailed architecture documentation
├── README.md               # This file
├── LICENSE                 # Project license
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
├── terraform/
│   ├── modules/           # Reusable Terraform modules
│   ├── environments/      # Environment-specific configurations
│   └── main.tf           # Root Terraform configuration
├── src/
│   ├── index.html        # Static website content
│   ├── assets/           # CSS, JS, images
│   └── examples/         # Architecture pattern examples
├── tests/
│   ├── unit/             # Unit tests for Terraform modules
│   ├── integration/      # End-to-end integration tests
│   └── security/         # Security scanning configurations
└── docs/
    ├── deployment.md     # Deployment procedures
    ├── monitoring.md     # Monitoring and alerting setup
    └── troubleshooting.md # Common issues and solutions
```

## 🔧 Key Components

### Infrastructure Modules

- **Network**: VPC, subnets, and routing configuration
- **Storage**: S3 buckets with intelligent tiering and replication
- **CDN**: CloudFront distribution with security headers
- **Security**: WAF rules, SSL certificates, and IAM policies
- **Monitoring**: CloudWatch dashboards, alarms, and log aggregation

### CI/CD Pipeline

- **Build**: Static asset compilation and optimization
- **Test**: Security scanning, performance testing, and validation
- **Deploy**: Automated deployment with rollback capabilities
- **Monitor**: Health checks and performance monitoring

## 💰 Cost Estimates

| Component | Monthly Cost (USD) | Annual Cost (USD) |
|-----------|-------------------|-------------------|
| S3 Storage & Requests | ~$0.30 | ~$3.60 |
| CloudFront CDN | ~$8.50 | ~$102.00 |
| Route 53 DNS | ~$0.90 | ~$10.80 |
| AWS WAF | ~$6.00 | ~$72.00 |
| Monitoring & Logs | ~$4.50 | ~$54.00 |
| Data Transfer | ~$9.00 | ~$108.00 |
| **Total** | **~$29.20** | **~$350.40** |

*Costs based on moderate traffic (100GB/month transfer, 1M requests)*

## 🔒 Security Features

- **OWASP Top 10 Protection**: AWS WAF with managed rule sets
- **TLS 1.3 Encryption**: End-to-end encryption with ACM certificates
- **Access Controls**: Least privilege IAM policies and S3 bucket policies
- **Security Headers**: HSTS, CSP, and X-Frame-Options via CloudFront
- **Monitoring**: Real-time security event logging and alerting

## 📊 Performance Metrics

- **Global Latency**: <100ms (95th percentile)
- **Availability**: 99.9% uptime SLA
- **Cache Hit Ratio**: >85% content delivery efficiency
- **Time to First Byte**: <200ms average response time

## 🛠️ Management Commands

```bash
# Infrastructure operations
tofu plan                    # Preview infrastructure changes
tofu apply                   # Apply infrastructure changes
tofu destroy                 # Tear down infrastructure

# Testing
bash tests/unit/run-tests.sh        # Run unit tests
bash tests/integration/run-tests.sh # Run integration tests
bash tests/security/scan.sh         # Security vulnerability scanning

# Monitoring
aws cloudwatch get-dashboard --dashboard-name StaticSite
aws logs tail /aws/cloudfront/access-logs --follow
```

## 📚 Documentation

- [**ARCHITECTURE.md**](./ARCHITECTURE.md) - Comprehensive architecture documentation with diagrams and cost analysis
- [**Deployment Guide**](./docs/deployment.md) - Step-by-step deployment procedures
- [**Monitoring Setup**](./docs/monitoring.md) - CloudWatch dashboards and alerting configuration
- [**Troubleshooting**](./docs/troubleshooting.md) - Common issues and resolution steps

## 🎯 Well-Architected Framework Alignment

This project demonstrates all six pillars of the AWS Well-Architected Framework:

1. **Operational Excellence**: Automated CI/CD, IaC, and monitoring
2. **Security**: Defense-in-depth with WAF, encryption, and access controls
3. **Reliability**: Multi-region replication and automated failover
4. **Performance Efficiency**: Global CDN and intelligent caching
5. **Cost Optimization**: Pay-as-you-consume with intelligent resource management
6. **Sustainability**: Serverless architecture minimizing environmental impact

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [docs/](./docs/) directory for detailed guides
- **Issues**: Report bugs or request features via GitHub Issues
- **Security**: Report security vulnerabilities privately to the maintainers

## 🏆 Acknowledgments

- AWS Well-Architected Framework for architectural guidance
- OpenTofu community for open-source infrastructure as code
- OWASP for security best practices and vulnerability frameworks

---

**Built with ❤️ using AWS Well-Architected principles and modern DevOps practices.**
