

# LedgerForge Project Context

## Current Phase

Phase 2 — Multi-Account Foundation

The import pipeline, validation framework and first live dashboard are complete.

Current engineering focus is evolving LedgerForge from an import engine into a financial operating system.

---

## Completed Milestones

- Import pipeline
- Statement normalization
- Institution detection
- Axis Bank account parser
- Direction resolution
- Import validation
- Import sessions
- Reactive dashboard
- Financial Snapshot
- Architecture documentation
- Product Vision
- Engineering Standards
- ADRs
- GitHub Copilot project instructions

---

## Current Priorities

1. AccountStore
2. Multi-account support
3. Money value type
4. Currency formatter
5. Exchange rate service
6. Import history
7. Dashboard powered by accounts

---

## Financial Principles

- Preserve imported financial truth.
- Native currency is never overwritten.
- Currency conversion is derived.
- Dashboard may present multiple display currencies.
- Every calculation must be deterministic and explainable.

---

## Reference Assets

Always prefer existing project references over assumptions.

Known references include:

- Budget workbook
- Approved dashboard sketches
- Axis Bank account statement
- Axis credit card statement
- CBQ account statement
- CBQ credit card statement

If additional references are required, request them before implementation.

---

## Development Workflow

1. Read project documentation.
2. Read ADRs.
3. Verify architecture.
4. Verify references.
5. Implement one sprint.
6. Build.
7. Test.
8. Commit.

---

## Definition of Success

LedgerForge should become the trusted financial operating system users open every day because it provides the clearest and most trustworthy understanding of their finances. Importing statements should become an invisible maintenance task supporting that goal.
