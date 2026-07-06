# LedgerForge AI Workflow

Before every implementation:

1. Read:
   - .github/context.md
   - copilot-instructions.md
   - prompts.md
   - ADR.md
   - Engineering Standards.md
   - Product Vision.md
   - Architecture_v1.0_Frozen.md
   - Database_v1_Architecture.md

2. Never modify architecture without updating documentation.

3. Every implementation must:
   - Build successfully.
   - Leave zero compile errors.
   - Preserve existing functionality.

4. Every sprint creates:

Implementation Reports/
Sprint##_Phase##_Report.md

5. Every new file must:
   - be added to Xcode navigator
   - be added to target membership
   - compile successfully

6. Never leave TODOs without listing them in the report.

7. Prefer protocol-oriented architecture.

8. Never bypass repository abstractions.
