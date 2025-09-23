# Contributing to AWS Static Website Infrastructure

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## 🤝 Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:

- **Be respectful**: Treat everyone with respect and kindness
- **Be collaborative**: Work together to solve problems
- **Be inclusive**: Welcome diverse perspectives and experiences
- **Be professional**: Focus on what is best for the community

## 🚀 Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/static-site.git
   cd static-site
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/<original-org>/static-site.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 🔧 Development Setup

### Prerequisites
- OpenTofu/Terraform >= 1.6.0
- AWS CLI configured
- GitHub CLI (gh) installed
- yamllint for YAML validation
- Checkov for security scanning

### Local Validation
Before submitting a PR, ensure your changes pass all checks:

```bash
# Terraform validation
tofu validate && tofu fmt -check

# YAML validation
yamllint -d relaxed .github/workflows/*.yml

# Security scanning
checkov -d terraform/
trivy config terraform/
```

## 📝 Contribution Guidelines

### Types of Contributions

#### 🐛 Bug Reports
- Use the [bug report issue template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include reproduction steps
- Provide environment details
- Attach relevant logs

#### ✨ Feature Requests
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md)
- Describe the use case
- Explain the expected behavior
- Consider implementation approach

#### 📚 Documentation
- Fix typos and clarify existing docs
- Add examples and use cases
- Improve troubleshooting guides
- Update architecture diagrams

#### 💻 Code Contributions
- Fix bugs
- Add features
- Improve performance
- Enhance security

### Pull Request Process

1. **Update Documentation**: Document any new features or changes
2. **Add Tests**: Include tests for new functionality
3. **Pass CI Checks**: Ensure all GitHub Actions workflows pass
4. **Update ROADMAP**: Add significant features to ROADMAP.md
5. **Request Review**: Tag maintainers for review

### PR Guidelines

#### Title Format
```
<type>(<scope>): <subject>

Types: feat, fix, docs, style, refactor, test, chore
Scope: terraform, workflows, docs, security
```

Examples:
- `feat(terraform): add CloudFront origin failover`
- `fix(workflows): resolve ANSI color output issues`
- `docs(security): update IAM policy documentation`

#### PR Description Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Local validation passed
- [ ] Security scans passed
- [ ] Tested in dev environment
- [ ] Documentation updated

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] All new and existing tests pass
```

## 🏗️ Architecture Guidelines

### Terraform/OpenTofu
- Follow existing module patterns
- Use consistent naming conventions
- Add variables for configurability
- Include outputs for module interfaces
- Document all variables and outputs

### GitHub Actions
- Keep workflows DRY (Don't Repeat Yourself)
- Use reusable workflows where possible
- Add appropriate timeouts
- Include error handling
- Document workflow inputs

### Security
- Never commit secrets or credentials
- Use OIDC authentication
- Follow least privilege principle
- Add security scanning for new components
- Document security implications

## 🧪 Testing

### Infrastructure Tests
- Add unit tests for new modules in `test/`
- Include both positive and negative test cases
- Test security configurations
- Validate cost optimization

### Integration Tests
- Test complete deployment workflows
- Verify cross-module interactions
- Validate environment configurations
- Check monitoring and alerting

## 📋 Review Process

### What We Look For
- **Code Quality**: Clean, maintainable, and follows patterns
- **Security**: No vulnerabilities or exposed secrets
- **Performance**: Efficient and cost-effective
- **Documentation**: Clear and comprehensive
- **Tests**: Adequate coverage and passing

### Review Timeline
- **Initial Response**: Within 2-3 business days
- **Review Completion**: Within 1 week for small changes
- **Merge Decision**: After all checks pass and approved

## 🎯 Priority Areas

We especially welcome contributions in these areas:

1. **Security Enhancements**: WAF rules, security policies
2. **Cost Optimization**: Resource efficiency improvements
3. **Testing**: Expanding test coverage
4. **Documentation**: Examples, tutorials, guides
5. **Multi-Region Support**: Global deployment capabilities

## 📚 Resources

- [Development Guide](.github/DEVELOPMENT.md)
- [Architecture Documentation](docs/architecture.md)
- [Project Roadmap](ROADMAP.md)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## 💬 Communication

- **GitHub Issues**: For bugs and feature requests
  - [Submit a bug report](.github/ISSUE_TEMPLATE/bug_report.md)
  - [Request a feature](.github/ISSUE_TEMPLATE/feature_request.md)
- **GitHub Discussions**: For questions and ideas
- **Pull Requests**: For code contributions

## 🙏 Recognition

Contributors will be recognized in:
- Release notes
- Contributors list
- Project documentation

Thank you for contributing to make this project better!