<!-- Project documents/Implementation Reports/Database_Architecture_Update_Report.md -->

# Database Architecture v1.0 — Update Report

Date: 2026-07-06

This report documents the focused, documentation-only update made to `Project documents/Database_v1_Architecture.md` to bring it into alignment with the project's ADRs, `Architecture_v1.0_Frozen.md`, `Product Vision.md` and `Engineering Standards.md`.

Summary

- Objective: Bring the Database v1 architecture document into closer alignment with project ADRs and the frozen architecture. This change set is documentation-only: no Swift code, project structure or database implementation was modified.
- Files updated: `Project documents/Database_v1_Architecture.md` (content edits only).

# Sections Updated

1. Import Coordination
   - Added a new `Import Coordination` section describing the `ImportCoordinator` responsibilities and scope. Emphasises orchestration (selection of Document Reader, institution detection, password resolution, creating ImportSessions, parser selection, validation coordination, persistence of validated objects and UI progress reporting). Clarifies that the ImportCoordinator does not perform parsing or business logic.

2. Financial Truth
   - Added a new `Financial Truth` section and a corresponding Top-level Goals bullet emphasising the separation between Source Truth, Derived Data and Presentation.

3. Parser Versioning
   - Extended the `import_profiles` section with explicit parser-versioning guidance: parser selection ordering (Institution → Document Type → Layout Version → Parser Version) and an explicit statement that parser versions are immutable.

4. Documents table
   - Extended the `documents` table with `statement_start_date`, `statement_end_date` and `document_type` columns. Added a recommended set of `document_type` values for common use-cases (bank_statement, credit_card_statement, brokerage_statement, insurance_statement, salary_statement, tax_document, unknown).

5. Import Sessions
   - Extended `import_sessions` with `reader_version`, `parser_version` and `layout_version` columns and added a note describing their use for long-term parser traceability and debugging.

6. Password Resolution
   - Added a `Password Resolution` section clarifying that Document Readers receive unlocked streams and that password resolution is handled by the orchestration layer using secure OS credential storage. Readers never perform decryption.

7. OCR Strategy
   - Added an `OCR Strategy` section describing how PDF Document Readers should determine extractable text and when to invoke OCR. Reaffirms OCR is a Document Reader implementation detail and transparent to downstream components.

8. SQLite Configuration
   - Inserted a `SQLite Configuration` section listing production-safe defaults (WAL journaling, foreign key enforcement, busy timeout, prepared statements, parameterized queries, background write queue) and marked them as mandatory for production builds.

# Consistency Checks Performed

- Terminology: Reconciled usages to prefer `Document Reader` / `Document Readers` where the original document described readers. Instances where the architecture referenced `Reader`/`Readers` were updated to `Document Reader(s)` for clarity and consistency with ADR language.
- ImportCoordinator: Added and used the `ImportCoordinator` term consistently in the orchestration descriptions.
- Reader/Parser responsibilities: Verified the document's description of responsibilities matches `Architecture_v1.0_Frozen.md` and ADR-012 (Separation of Readers and Parsers). Clarified that Document Readers are extraction-only and Parsers handle financial interpretation.
- Validation-before-persistence: Verified that `import_sessions.validation_status`, `validation_issues` and `transactions.is_trusted` semantics remain unchanged and consistent with ADR-010.
- Multi-currency principles: Confirmed the multi-currency model, `amount_decimal` + `amount_minor` approach and exchange rate append-only policy are unchanged.
- No new architectural concepts beyond those specified by the user were introduced.

# Architectural Improvements

- Made the orchestration responsibilities explicit by introducing `ImportCoordinator` and separating coordination concerns from parsing/validation logic.
- Improved traceability guidance by adding reader/parser/layout versioning to `import_sessions`.
- Strengthened the document model by adding explicit statement-level start/end dates and a typed `document_type` field to `documents` to aid classification, UX and deduplication logic.
- Documented mandatory SQLite runtime configuration guidance (production-safe defaults) so implementation teams have a clear checklist when hardening the DB layer.

# Potential Follow-up Recommendations

1. Add DDL examples and migration guidance for the new `documents` and `import_sessions` fields in the schema DDL and migration scripts (Phase 2C). Ensure backfill strategies are planned for `statement_start_date`, `statement_end_date` and version columns.
2. Ensure `DocumentReader` implementations and the ImportCoordinator propagate `reader_version`, `parser_version`, and `layout_version` values at import time so the traceability columns are populated consistently.
3. Update Developer onboarding docs to describe ImportCoordinator responsibilities and how to add/upgrade parsers and reader versions.

End of report.
