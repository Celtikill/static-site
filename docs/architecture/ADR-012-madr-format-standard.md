# 12. MADR Format Standard for Architecture Decision Records

Date: 2024-11-12
Status: Accepted
Deciders: Engineering Team
Technical Story: Standardize ADR format for consistency, completeness, and community alignment

## Context and Problem Statement

The project has created multiple Architecture Decision Records (ADRs 001-011) documenting key architectural decisions. However, these ADRs used inconsistent formats, making them harder to navigate and compare. Some were verbose with custom sections, others were minimal.

**Issues Identified**:
1. **Inconsistent structure**: Each ADR had different section organization
2. **Variable completeness**: Some ADRs lacked "Considered Options" or "Pros and Cons" sections
3. **Community misalignment**: Custom format doesn't align with established ADR standards
4. **Template absence**: No template file to guide future ADR creation
5. **Maintenance burden**: Inconsistent formats harder to update systematically

How should we standardize ADR format to ensure consistency, completeness, and alignment with community best practices?

## Decision Drivers

* **Consistency**: All ADRs follow same structure for easy navigation
* **Completeness**: Template ensures no critical sections omitted
* **Community alignment**: Use established standard (don't reinvent)
* **Searchability**: Consistent sections make finding information easier
* **Maintainability**: Standard format easier to update and refactor
* **Onboarding**: New contributors immediately understand ADR structure
* **Tool support**: Standard format enables potential tooling (linters, generators)
* **Comparison**: Easy to compare decision patterns across ADRs

## Considered Options

* **Option 1**: MADR (Markdown Architecture Decision Records) format (Chosen)
* **Option 2**: Nygard's original ADR format (minimal)
* **Option 3**: Custom format with project-specific sections
* **Option 4**: Y-statements format (minimalist)

## Decision Outcome

**Chosen option: "MADR (Markdown Architecture Decision Records)"** because it provides comprehensive structure, community support, and balance between thoroughness and usability.

### Implementation

**MADR Standard**: https://github.com/adr/madr

**Required Structure**:

```markdown
# [number]. [title]

Date: YYYY-MM-DD
Status: [Accepted | Rejected | Deprecated | Superseded]
Deciders: [who decided]
Technical Story: [short description of driver/context]

## Context and Problem Statement

[Describe the context and problem in 2-5 paragraphs]
[End with clear question that decision answers]

## Decision Drivers

* [driver 1]
* [driver 2]
* [driver 3]
* ...

## Considered Options

* [option 1]
* [option 2]
* [option 3]
* ...

## Decision Outcome

**Chosen option: "[option]"** because [justification sentence].

### Implementation

[Technical implementation details]
[Code examples, configurations, or architectural patterns]

### Positive Consequences

* [positive consequence 1]
* [positive consequence 2]
* ...

### Negative Consequences

* [negative consequence 1]
* [negative consequence 2]
* ...

## Pros and Cons of the Options

### [option 1]

* Good, because [argument a]
* Good, because [argument b]
* Bad, because [argument c]
* Bad, because [argument d]

### [option 2]

* Good, because [argument a]
* Bad, because [argument b]
* ...

## Links

* [link 1]
* [link 2]
* ...

---

**Last Updated**: YYYY-MM-DD
**Review Date**: YYYY-MM-DD ([timeframe] - [what to evaluate])
```

**Status Values**:
- **Accepted**: Decision is approved and active
- **Deprecated**: Decision superseded but still in use
- **Superseded**: Replaced by another ADR (link to replacement)
- **Rejected**: Considered but not adopted

**Naming Convention**: `ADR-NNN-kebab-case-title.md`

**Numbering**: Sequential integers with leading zeros (001, 002, ..., 012, ...)

### Positive Consequences

* **Consistency**: All ADRs follow same structure
* **Completeness**: Template ensures all critical sections included
* **Community alignment**: Uses widely-adopted MADR standard
* **Onboarding speed**: New contributors understand ADR format immediately
* **Tool support**: Standard format enables linters, generators, indexers
* **Searchability**: Consistent sections make grep/search more effective
* **Comparison**: Easy to compare decision patterns across ADRs
* **Professional**: Industry-standard format improves project credibility

### Negative Consequences

* **Refactoring required**: Existing ADRs needed conversion to MADR format (completed)
* **Verbosity**: MADR more detailed than minimal formats (but thoroughness valuable)
* **Learning curve**: Contributors must learn MADR structure (mitigated by template)

## Pros and Cons of the Options

### Option 1: MADR Format (Chosen)

* Good, because widely adopted community standard (not custom)
* Good, because comprehensive structure ensures completeness
* Good, because balances thoroughness with usability
* Good, because GitHub support and tooling available
* Good, because clear guidance on each section's purpose
* Good, because "Pros and Cons" section forces evaluation of alternatives
* Good, because extensible (can add project-specific sections)
* Bad, because more verbose than minimal formats
* Bad, because required refactoring existing ADRs

### Option 2: Nygard's Original ADR Format

* Good, because simplest possible format (Title, Status, Context, Decision, Consequences)
* Good, because fast to write
* Good, because original ADR format (historical significance)
* Bad, because too minimal (no "Considered Options" or "Pros and Cons")
* Bad, because lacks structure for comparing alternatives
* Bad, because doesn't capture decision drivers explicitly
* Bad, because no implementation details section

### Option 3: Custom Format

* Good, because tailored to project needs
* Good, because complete flexibility
* Bad, because not community standard (no external tooling)
* Bad, because higher maintenance burden
* Bad, because harder for new contributors (unfamiliar format)
* Bad, because reinventing the wheel
* Bad, because inconsistent with other projects

### Option 4: Y-Statements Format

* Good, because ultra-concise (one-sentence decisions)
* Good, because forces clarity
* Bad, because too minimal for complex decisions
* Bad, because no room for rationale or alternatives
* Bad, because loses valuable context
* Bad, because not suitable for architectural decisions (better for user stories)

## Implementation Details

### ADR Template Location

**File**: `docs/architecture/ADR-TEMPLATE.md`

Provides copy-paste starting point for new ADRs with:
- Complete MADR structure
- Placeholder text for each section
- Examples for common section types
- Guidance on filling out each section

### Refactoring Completed

All existing ADRs converted to MADR format (November 2024):
- ✅ ADR-001: IAM Permission Strategy
- ✅ ADR-002: Branch-Based Deployment Routing
- ✅ ADR-003: Manual Semantic Versioning
- ✅ ADR-004: Conventional Commits Enforcement
- ✅ ADR-005: Deployment Documentation Architecture
- ✅ ADR-006: Prefer Terraform Over Bash
- ✅ ADR-007: Emergency Operations Workflow
- ✅ ADR-008: Bash 3.2 Compatibility Enforcement
- ✅ ADR-009: Environment Variable Configuration
- ✅ ADR-010: Prevent Hardcoded Credentials
- ✅ ADR-011: Secrets Management in Documentation
- ✅ ADR-012: MADR Format Standard (this document)

### Section Guidance

**Context and Problem Statement**:
- 2-5 paragraphs describing background
- End with clear question that decision answers
- Example: "How should we [do X] to achieve [Y] while maintaining [Z]?"

**Decision Drivers**:
- Bullet list of factors influencing decision
- Use bold formatting for driver name: `* **Factor**: Description`
- Order by importance (most critical first)

**Considered Options**:
- List all options evaluated (not just chosen one)
- Mark chosen option: `* **Option 1**: Description (Chosen)`
- Include rejected alternatives (valuable for future reference)

**Decision Outcome**:
- Start with: `**Chosen option: "[name]"** because [justification].`
- Follow with ### Implementation, ### Positive Consequences, ### Negative Consequences

**Pros and Cons of Options**:
- Evaluate EVERY option (including rejected ones)
- Use "Good, because" and "Bad, because" format
- Be honest about tradeoffs of chosen option

**Links**:
- Link to implementation files
- Link to related ADRs
- Link to external references (RFCs, blog posts, documentation)

### When to Create an ADR

Create new ADR when:
- ✅ Making significant architectural decision
- ✅ Choosing between multiple technical approaches
- ✅ Establishing project-wide standard or pattern
- ✅ Decision will impact future development

Do NOT create ADR for:
- ❌ Implementation details (use code comments)
- ❌ Temporary workarounds (use TODO comments)
- ❌ Obvious choices with no alternatives
- ❌ Decisions easily reversed without consequence

### ADR Lifecycle

**Creation**: Use ADR-TEMPLATE.md, assign next sequential number
**Review**: Team reviews ADR before "Accepted" status
**Updates**: Update "Last Updated" date, preserve decision date
**Deprecation**: Change status to "Deprecated", add explanation
**Superseding**: Change status to "Superseded", link to replacement ADR

## Links

* **MADR Standard**: https://github.com/adr/madr - Official MADR format specification
* **MADR Documentation**: https://adr.github.io/madr/ - Detailed guidance on using MADR
* **Original ADR**: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions - Nygard's original ADR pattern
* **ADR GitHub Organization**: https://adr.github.io/ - Community resources for ADRs
* **Template**: [ADR-TEMPLATE.md](./ADR-TEMPLATE.md) - Project ADR template file
* **All ADRs**: [docs/architecture/](.) - Complete list of project ADRs

---

**Last Updated**: 2024-11-12
**Review Date**: 2025-05-12 (6 months - evaluate format effectiveness and consistency)
