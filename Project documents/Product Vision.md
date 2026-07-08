# LedgerForge – Product Vision

## Mission

LedgerForge is an offline-first personal financial operating system that consolidates every aspect of a user's financial life into a single trustworthy workspace.


The primary product is the financial dashboard. Document import, OCR, profile learning and automation exist only to keep that dashboard accurate with minimal manual effort.

LedgerForge is designed from the outset as a multi-currency financial operating system. Every monetary value retains its native currency, while dashboards and reports present configurable base and secondary currency views using transparent, auditable exchange rates.

---

# Vision

A user should be able to open LedgerForge at any time and immediately understand:

- Current net worth
- Net worth across multiple currencies
- Cash available
- Investment allocation
- Budget performance
- Upcoming financial obligations
- Financial health
- Currency exposure
- Changes in wealth across accounts, currencies and investments
- Important changes requiring attention

The application should answer financial questions instead of simply storing financial data.

---

# Product Principles

Every feature should satisfy at least one of these goals:

1. Reduce manual work.
2. Increase confidence.
3. Surface meaningful financial insight.
4. Preserve financial truth.


LedgerForge should never sacrifice accuracy for convenience. Every calculation must remain deterministic, explainable and reproducible.

Approved reference fixtures define financial truth for supported institutions and formats. When the same statement is available in multiple formats, such as CSV and PDF, LedgerForge must preserve equivalent observable financial results across those formats.

---

# Core Experience

LedgerForge should feel like a financial command center rather than an importer.

Primary modules:

- Dashboard
- Accounts
- Transactions
- Documents
- Import History
- Investments
- Budget & Cash Flow
- Multi-Currency Dashboard
- Financial Timeline
- Financial Intelligence
- Rules & Automation
- Settings

---

# User Experience Philosophy

LedgerForge should feel like a native macOS application rather than an import utility.

The application shell, navigation and interaction model are defined by `UI_UX_v1.0_Frozen.md`.

Implementation should consistently reinforce the following principles:

- Dashboard-first experience.
- Persistent sidebar navigation.
- Context-sensitive toolbar.
- Information density without visual clutter.
- Developer tooling separated from normal user workflows.
- Import workflows presented as temporary tasks rather than permanent application modules.

The user should primarily experience financial insight. Importing statements should feel like maintenance rather than the purpose of the application.

# Automation Philosophy
# Automation Philosophy

LedgerForge should never ask the user for information it can determine automatically.

The system should continuously learn:

- Statement formats
- Institutions
- Categories
- Recurring transactions
- Salary patterns
- Subscriptions
- Investments
- User preferences

Every successful import should improve future imports.

Automation should quietly disappear into the background. The user should primarily experience trustworthy financial insights rather than the mechanics of importing and processing documents.

---

# Intelligent Document Processing

LedgerForge treats every imported document as structured financial evidence rather than as a file.

Supported sources include:

- PDF statements
- CSV exports
- XLS/XLSX exports
- TXT exports (where provided by institutions)

Every import follows the same deterministic pipeline:
Every stage preserves explainability and traceability so identical financial evidence always produces identical financial results.

1. Coordinate the import through the Unified Import Framework.
2. Resolve an optional password through the import coordination layer when required.
3. Select the appropriate reader for the file format.
4. Extract raw document contents into RawDocument.
5. Identify the financial institution.
6. Determine the statement type (bank account, credit card, investment, salary, etc.).
7. Select the appropriate parser using deterministic rules.
8. Execute the Statement Parser.
9. Produce an immutable FinancialDocument.
10. Validate the extracted financial data.
11. Persist validated financial data through repository protocols.
12. Refresh runtime stores from the validated repository state.

Institution detection should rely on document fingerprints, metadata, recurring keywords, visual structure, and previous successful imports rather than filenames.

Statement layouts and institution formats may evolve over time. LedgerForge should automatically recognize new layouts, preserve compatibility with older formats, and improve recognition without compromising deterministic parsing or financial truth.

The import pipeline should be format-independent. Whether data originates from PDF, CSV, XLS/XLSX or TXT, downstream processing should produce identical financial truth after reader-specific extraction and deterministic parser execution.

Reader-specific adapters (CSV, PDF, XLS/XLSX and future formats) are responsible only for producing equivalent financial evidence. Once a FinancialDocument has been produced, downstream validation, persistence and presentation must remain independent of the original file format.

Repository persistence must never bypass validation. Dashboards, accounts and future analytics consume repository-backed runtime state rather than parser output directly.

Importing documents should require little or no user interaction beyond selecting the file.

The statement, not the file format, is the source of financial truth. Equivalent CSV, PDF and future spreadsheet representations of the same statement should reconcile to the same approved expected results.
---

# Explainable Intelligence

Every automatic decision must be:

- Explainable
- Inspectable
- Reversible
- Auditable

Users should always be able to understand why LedgerForge reached a conclusion.

Every automated financial calculation should identify the data source, exchange rate (where applicable), and reasoning used to produce the result.

---

# Long-Term Goal

LedgerForge should become the trusted financial operating system that users open every day because it provides the clearest, most accurate understanding of their financial life. Importing documents becomes an almost invisible maintenance activity while repository-backed dashboards evolve into a living financial operating system that users trust and return to every day.
