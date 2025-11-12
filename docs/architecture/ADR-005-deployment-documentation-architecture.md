# 5. Deployment Documentation Architecture

Date: 2024-10-16
Status: Partially Implemented
Deciders: Engineering Team
Technical Story: Documentation proliferation requires layered architecture for different user journeys

## Context and Problem Statement

The static website infrastructure project accumulated multiple overlapping documentation files during rapid development. Three documents covered deployment information with significant overlap, causing confusion about which document to consult for specific tasks.

**Existing Documentation State**:
- `PIPELINE-TEST-PLAN.md` (490 lines): Detailed testing plan and IAM permission evolution
- `docs/deployment.md` (488 lines): Advanced deployment strategies and patterns
- `docs/ci-cd.md` (642 lines): Complete CI/CD pipeline documentation

**Issues Identified**:
1. **Overlap**: All three documents covered deployment workflows
2. **Discovery**: Unclear which document to read first
3. **Maintenance**: Updates required in multiple places
4. **Audience**: Different documents for different skill levels mixed together
5. **Historical Context**: Important decision context buried in test plans

How should we organize deployment documentation to serve multiple audiences (new users, experienced operators, architects) while minimizing duplication and maintaining historical context?

## Decision Drivers

* **Clear user journeys**: Logical progression from quick start to deep dive
* **Separation of concerns**: How-to vs. why vs. reference documentation
* **Minimize duplication**: Single source of truth for each topic
* **Discoverability**: Clear naming indicating document purpose
* **Maintainability**: Easy to update without breaking references
* **Multiple audiences**: Quick start (<10 min), reference, deep dive, historical context
* **Time to value**: New developers productive within 10 minutes
* **Historical preservation**: Decision context not lost over time

## Considered Options

* **Option 1**: Layered Documentation Architecture with ADRs (Chosen)
* **Option 2**: Single comprehensive deployment guide
* **Option 3**: Wiki-style linked documentation
* **Option 4**: Code-adjacent documentation (docs in scripts/)

## Decision Outcome

**Chosen option: "Layered Documentation Architecture with ADRs"** because it provides clear separation between quick-start, reference, and architectural rationale while preserving historical context.

### Implementation

**Planned Structure** (October 2024):
```
Repository Root
├── README.md (Quick links, current status)
├── CONTRIBUTING.md (Development workflow, PR guidelines)
│
├── docs/
│   ├── QUICK-START.md (5-minute deployment guide)
│   ├── RELEASE-PROCESS.md (Production release workflow)
│   ├── deployment.md (Advanced strategies)
│   ├── ci-cd.md (Pipeline deep dive)
│   │
│   ├── architecture/
│   │   ├── ADR-001-iam-permission-strategy.md
│   │   ├── ADR-002-branch-based-deployment-routing.md
│   │   ├── ADR-003-manual-semantic-versioning.md
│   │   ├── ADR-004-conventional-commits-enforcement.md
│   │   └── ADR-005-deployment-documentation-architecture.md
│   │
│   └── archive/
│       └── 2024-10-16-pipeline-test-plan.md
```

**Actual Implementation** (October-November 2024):
The project evolved differently based on team experience:
- Quick-start content merged into unified `DEPLOYMENT.md` instead of separate file
- Release process documented in `CONTRIBUTING.md` and `ROADMAP.md` instead of dedicated file
- Progressive disclosure achieved through `docs/README.md` navigation structure
- ADR documents created as planned
- Archive directory deemed unnecessary (context captured in ADRs)

**Implementation Variance Rationale**:
1. **Unified Deployment Guide**: Single `DEPLOYMENT.md` with sections more maintainable than multiple small files
2. **Release Process Integration**: Release workflow fits naturally in `CONTRIBUTING.md` alongside PR workflow
3. **Archive Decision**: Original test plan information captured in ADR-001, separate archive unnecessary
4. **Progressive Disclosure**: `docs/README.md` navigation provides intended user journey without file proliferation

### Document Purposes

**Quick Start Documents** (Time to value: <10 minutes):
- `README.md`: Current deployment status, quick links, environment URLs
- `CONTRIBUTING.md`: Developer workflow, conventional commits, PR requirements
- `DEPLOYMENT.md`: Unified deployment guide with progressive disclosure

**Deep Dive Documents** (Reference and understanding):
- `docs/deployment.md`: Advanced deployment strategies, cost optimization, rollback procedures
- `docs/ci-cd.md`: BUILD → TEST → RUN pipeline architecture, workflow routing, troubleshooting

**Architectural Context** (Why decisions were made):
- `docs/architecture/ADR-*.md`: Architecture Decision Records documenting rationale for major decisions

### Information Flow

```
New User → README.md → QUICK-START/DEPLOYMENT.md → Success
Developer → CONTRIBUTING.md → PR Workflow → Merge
Release Manager → RELEASE-PROCESS → Deploy Production
Architect → ADR Documents → Understand Rationale
```

### Positive Consequences

* **Clear user journeys**: Readers know where to start based on their role
* **Reduced duplication**: Single source of truth per topic
* **Maintainability**: Updates in one place, cross-references stay valid
* **Discoverability**: Meaningful names aid navigation (QUICK-START vs. deployment.md)
* **Onboarding speed**: New developers productive in 5-10 minutes
* **Historical preservation**: ADRs document decision context and evolution
* **Flexible evolution**: Actual implementation adapted to team needs while maintaining core objectives

### Negative Consequences

* **Navigation required**: Can't read single document for full picture
* **Cross-references maintenance**: Links between documents must stay updated
* **Learning curve**: New contributors must learn documentation structure
* **Redundancy risk**: Temptation to duplicate content instead of linking

## Pros and Cons of the Options

### Option 1: Layered Documentation Architecture (Chosen)

* Good, because provides clear entry points for different audiences
* Good, because separates concerns (how-to vs. why vs. reference)
* Good, because minimizes duplication while preserving context
* Good, because ADRs create reusable architectural knowledge
* Good, because progressive disclosure reveals complexity gradually
* Good, because supports multiple learning styles and speeds
* Bad, because requires navigation between multiple files
* Bad, because cross-references need maintenance
* Bad, because more files to manage

### Option 2: Single Comprehensive Deployment Guide

* Good, because everything in one place
* Good, because no cross-references to maintain
* Good, because simple mental model
* Bad, because too long for quick reference (hundreds of lines)
* Bad, because intimidates new users
* Bad, because mixes audiences (beginner and advanced)
* Bad, because difficult to maintain (changes affect entire document)
* Bad, because no separation between how-to and why

### Option 3: Wiki-Style Linked Documentation

* Good, because flexible organization
* Good, because easy to add new pages
* Bad, because lacks structure and navigation
* Bad, because wiki separate from codebase (synchronization issues)
* Bad, because no version control with code
* Bad, because search-dependent (discoverability issues)
* Bad, because links break easily

### Option 4: Code-Adjacent Documentation

* Good, because documentation lives with relevant code
* Good, because reduces context switching
* Bad, because hard to find documentation starting point
* Bad, because duplicates documentation across scripts
* Bad, because no high-level overview or architecture view
* Bad, because doesn't serve non-code documentation needs

## Implementation Details

### Documentation Organization Principles

**Principle 1: Progressive Disclosure**
- Start simple (quick-start), reveal complexity as needed (advanced)
- Links guide users to next level of detail
- No need to read everything to accomplish task

**Principle 2: Single Source of Truth**
- Each topic has one authoritative document
- Other documents link to authority (not duplicate)
- Updates happen in one place

**Principle 3: Audience-Driven Structure**
- New user path: README → QUICK-START → Success
- Developer path: CONTRIBUTING → PR → Merge
- Release manager path: RELEASE-PROCESS → Deploy
- Architect path: ADRs → Understanding

**Principle 4: Meaningful Names**
- QUICK-START (implies fast)
- RELEASE-PROCESS (implies steps)
- deployment.md (implies comprehensive)
- ADR-NNN (implies decision record)

### Risk Mitigations

**Risk**: Users don't discover appropriate documentation
- README.md has clear "How do I...?" links
- Each doc cross-references related docs
- Breadcrumbs at top of each document

**Risk**: Documentation becomes stale
- Each ADR has review date
- PR template includes "Update docs?" checklist
- Quarterly documentation review

**Risk**: ADRs proliferate excessively
- Only create ADR for significant architectural decision
- Combine related decisions in single ADR
- Update existing ADR vs. create new when appropriate

### Impact Assessment

The actual implementation achieves the ADR's core objectives:
- ✅ Clear user journeys (via docs/README.md navigation)
- ✅ Progressive disclosure (section-based organization)
- ✅ Reduced duplication (unified files prevent drift)
- ✅ Multiple audiences served (index directs to appropriate docs)
- ✅ Maintainability (fewer files to keep in sync)

The variance represents evolution based on team experience, not failure to implement. The spirit of the ADR (layered, audience-driven documentation) was achieved through different file organization.

## Links

* **Implementation**: [docs/README.md](../README.md) - Documentation index and navigation
* **Implementation**: [CONTRIBUTING.md](../../CONTRIBUTING.md) - Developer workflow guide
* **Implementation**: [DEPLOYMENT.md](../../DEPLOYMENT.md) - Unified deployment guide
* **Related ADRs**: ADR-001 (IAM Permission Strategy), ADR-002 (Branch-Based Routing), ADR-003 (Manual Versioning), ADR-004 (Conventional Commits)
* **Diátaxis Framework**: https://diataxis.fr/ - Tutorial, how-to, reference, explanation
* **Write the Docs**: https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/ - Documentation structure
* **ADR Pattern**: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions - Nygard's Architecture Decision Records

---

**Last Updated**: 2024-10-16
**Review Date**: 2025-01-16 (3 months - evaluate documentation effectiveness)
