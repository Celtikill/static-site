# Contributing Guide

Thank you for your interest in contributing to the AWS Static Website Infrastructure project!

## Documentation Standards

### File Organization

```
docs/
├── README.md              # Documentation index
├── quick-start.md         # Quick start guide
├── guides/                # Step-by-step instructions
│   ├── iam-setup.md
│   ├── deployment-guide.md
│   ├── security-guide.md
│   ├── testing-guide.md
│   └── troubleshooting.md
├── reference/             # Technical reference
│   ├── cost-estimation.md
│   ├── monitoring.md
│   └── compliance.md
└── development/           # Developer resources
    ├── ux-guidelines.md
    ├── workflow-conditions.md
    └── policy-examples.md
```

### Writing Guidelines

1. **Clear Headings**: Use descriptive, hierarchical headings
2. **Code Examples**: Include working code snippets with proper syntax highlighting
3. **Links**: Use relative links for internal docs, absolute for external
4. **Consistency**: Follow established patterns and terminology
5. **Accessibility**: Write at 11th-grade reading level, define technical terms

### Documentation Templates

#### Guide Template

```markdown
# Guide Title

Brief description of what this guide covers.

## Prerequisites

- Requirement 1
- Requirement 2

## Overview

High-level explanation of the process.

## Step-by-Step Instructions

### Step 1: Action Name

Detailed instructions...

```bash
# Code example
command --option value
```

### Step 2: Next Action

Continue with next step...

## Verification

How to verify the setup worked:

```bash
# Test command
test-command
```

## Troubleshooting

Common issues and solutions...

## Next Steps

What to do after completing this guide.
```

#### Reference Template

```markdown
# Reference Title

## Overview

What this document covers.

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| option1 | string | "value" | Description |

## API Reference

### Function Name

Description of the function.

**Parameters:**
- `param1` (string): Description
- `param2` (number): Description

**Returns:**
- Type: Description

**Example:**
```javascript
example code
```

## Related Resources

- [Related Guide](../guides/guide.md)
- [External Link](https://example.com)
```

## Code Standards

### Terraform

- Use consistent naming: `project-environment-resource`
- Include comments for complex logic
- Use variables for configurable values
- Follow HashiCorp style guide

```hcl
# Good
resource "aws_s3_bucket" "static_site" {
  bucket = "${var.project_name}-${var.environment}-${random_id.suffix.hex}"
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-static-site"
  })
}

# Bad  
resource "aws_s3_bucket" "bucket" {
  bucket = "my-bucket-123"
}
```

### GitHub Actions

- Pin actions to specific commit SHAs
- Use descriptive job and step names
- Include timeout values
- Add comments for complex logic

```yaml
# Good
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
    
# Bad
- uses: aws-actions/configure-aws-credentials@v4
```

## Testing Standards

### Unit Tests

- Test all Terraform modules
- Verify security configurations
- Check resource relationships
- Validate outputs

```bash
# Test structure
test_function() {
    local test_name="Descriptive test name"
    
    if condition; then
        pass_test "$test_name" "Success message"
    else
        fail_test "$test_name" "Failure message"
    fi
}
```

### Documentation Tests

Before submitting documentation:

1. **Spell Check**: Use spell checker
2. **Link Check**: Verify all links work
3. **Code Test**: Test all code examples
4. **Review**: Have someone else review

## Pull Request Process

### 1. Before You Start

- Check existing issues and PRs
- Create an issue to discuss large changes
- Fork the repository

### 2. Making Changes

```bash
# Create feature branch
git checkout -b feature/description

# Make your changes
# Test your changes
# Commit with clear messages

# Push changes
git push origin feature/description
```

### 3. Pull Request Requirements

- [ ] Clear description of changes
- [ ] Documentation updated if needed
- [ ] Tests pass locally
- [ ] No merge conflicts
- [ ] Follows code standards

### 4. Review Process

1. Automated checks must pass
2. Code review by maintainers
3. Address feedback
4. Approved PRs are merged

## Issue Guidelines

### Bug Reports

Include:
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Error messages
- Screenshots if applicable

### Feature Requests

Include:
- Problem description
- Proposed solution
- Alternative solutions considered
- Additional context

### Documentation Issues

Include:
- Which documentation is unclear
- What information is missing
- Suggested improvements

## Security

### Reporting Security Issues

**DO NOT** open public issues for security vulnerabilities.

Email security details to: [security@example.com]

Include:
- Vulnerability description
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Security Guidelines

- Never commit credentials
- Use placeholder values in examples
- Follow least privilege principle
- Keep dependencies updated

## Getting Help

- Check documentation in `/docs`
- Search existing issues
- Ask questions in discussions
- Join community channels

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes for major contributions
- Project documentation for significant improvements

Thank you for contributing to making this project better!