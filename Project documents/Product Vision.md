# LedgerForge – Product Vision

## Mission

LedgerForge is an offline-first personal financial operating system that consolidates every aspect of a user's financial life into a single trustworthy workspace.


The primary product is the financial dashboard. Document import, OCR, profile learning and automation exist only to keep that dashboard accurate with minimal manual effort.

LedgerForge is designed from the outset as a multi-currency financial operating system. Every monetary value retains its native currency, while dashboards and reports present configurable base and secondary currency views using transparent, auditable exchange rates.

LedgerForge is designed for private personal use and is intentionally optimized for a single user's financial workflow rather than broad commercial configurability.

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

# Financial Identity

LedgerForge models financial entities rather than merely financial institutions.

A financial institution may contain multiple independent financial entities, including:

- Bank accounts
- Credit cards
- Loans
- Brokerage accounts
- Retirement accounts
- Future financial products

Every imported document should resolve to a single financial entity using verified identifiers wherever possible.

Preferred identifiers include:

- Account numbers
- IBANs
- Credit card numbers
- Broker account IDs
- Future investment identifiers such as folio numbers

Display names exist only for presentation.

Repository identifiers remain immutable throughout the lifetime of the application.

Financial entities become the permanent owners of financial history. Documents, statements and transactions exist to describe activity occurring within those entities.

---

# Product Principles

Every feature should satisfy at least one of these goals:

1. Reduce manual work.
2. Increase confidence.
3. Surface meaningful financial insight.
4. Preserve financial truth.

LedgerForge should never sacrifice accuracy for convenience.

Every calculation must remain deterministic, explainable and reproducible.

Approved reference fixtures define financial truth for supported institutions and formats. When the same statement is available in multiple formats, such as CSV and PDF, LedgerForge must preserve equivalent observable financial results across those formats.

Additional architectural principles:

- Financial entities are more important than financial institutions.
- Repository identity never changes.
- Display names are presentation only.
- Import order must never change the final financial truth.
- Original financial data is immutable.
- Derived analytics are calculated separately.
- Internal transfers between financial entities owned by the user must never alter income, expenses or net worth.
- Multi-currency reporting must preserve original transaction values and derive converted values independently.

---

# Core Experience

LedgerForge should feel like a financial operating system rather than an importer.

Primary application modules:

- Dashboard
- Salary & Planning
- Accounts
- Transactions
- Imports
- Investments
- Multi-Currency Dashboard
- Financial Timeline
- Financial Intelligence
- Rules & Automation
- Settings

The Dashboard remains the primary destination.

Salary & Planning becomes the user's monthly financial planning workspace.

Import workflows remain temporary maintenance tasks rather than permanent destinations within the application.

Every other module exists to support accurate, explainable and actionable financial insight.

---

# User Experience Philosophy

LedgerForge should feel like a native macOS application rather than an import utility.

The application shell, navigation and interaction model are defined by `UI_UX_v1.0_Frozen.md`.

The approved visual system is frozen around the Deep Indigo dark mode theme.

`Project documents/UI Assets/Approved/DesignBoard_v2.0.png` is the master UI reference.

Individual approved assets define screen-level implementation details.

`AppIcon_v1.0.png` is the approved application icon.

Implementation sprints translate approved UI assets into SwiftUI. They must not redesign the approved visual language during implementation.

Implementation should consistently reinforce the following principles:

- Dashboard-first experience.
- Persistent sidebar navigation.
- Context-sensitive toolbar.
- Information density without visual clutter.
- Developer tooling separated from normal user workflows.
- Import workflows presented as temporary tasks rather than permanent application modules.

The user should primarily experience financial insight. Importing statements should feel like maintenance rather than the purpose of the application.

# Automation Philosophy

LedgerForge should never ask the user for information it can determine automatically.

LedgerForge should automate reasoning before automating data entry.

Small amounts of manual input are acceptable when they avoid fragile automation.

Automation should primarily focus on:

- Reconciliation
- Financial understanding
- Relationship discovery
- Intelligent classification
- Decision support

The system should continuously learn:

- Statement formats
- Institutions
- Financial entities
- Categories
- Recurring transactions
- Salary patterns
- Subscriptions
- Investments
- User preferences

Every successful import should improve future imports.

Automation should quietly disappear into the background.

The user should primarily experience trustworthy financial insight rather than the mechanics of importing and processing documents.

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

1. Coordinate the import through ImportCoordinator.
2. Resolve an optional password through PasswordProvider.
3. Select the appropriate Reader using ReaderRegistry.
4. Extract the file into RawDocument.
5. Perform Institution Detection.
6. Perform Statement Classification.
7. Select the appropriate Statement Parser.
8. Produce an immutable FinancialDocument.
9. Validate the financial document.
10. Execute Fingerprinting & Duplicate Detection.
11. Persist validated, non-duplicate financial data through repository boundaries.
12. Refresh runtime stores exclusively through RepositoryStoreHydrator.

Institution detection should rely on document fingerprints, metadata, recurring keywords, visual structure, and previous successful imports rather than filenames.

Statement layouts and institution formats may evolve over time. LedgerForge should automatically recognize new layouts, preserve compatibility with older formats, and improve recognition without compromising deterministic parsing or financial truth.

The import pipeline should be format-independent. Whether data originates from PDF, CSV, XLS/XLSX or TXT, downstream processing should produce identical financial truth after reader-specific extraction and deterministic parser execution.

Reader-specific adapters (CSV, PDF, XLS/XLSX and future formats) are responsible only for producing equivalent financial evidence. Once a FinancialDocument has been produced, downstream validation, persistence and presentation must remain independent of the original file format.

Repository persistence must never bypass validation. Dashboards, accounts and future analytics consume repository-backed runtime state rather than parser output directly.

Importing documents should require little or no user interaction beyond selecting the file.

The statement, not the file format, is the source of financial truth. Equivalent CSV, PDF and future spreadsheet representations of the same statement should reconcile to the same approved expected results.
---

# Financial Intelligence

LedgerForge should progressively evolve beyond document processing into financial understanding.

Financial intelligence builds upon deterministic document processing and repository-backed financial truth.

Future intelligence should include:

- Statement continuity
- Historical backfill imports
- Overlap-aware importing
- Duplicate detection
- Money journey reconstruction
- Internal transfer recognition
- Salary verification
- Retirement tracking
- Investment understanding
- Cash-flow planning
- Financial forecasting
- Cross-account reconciliation

LedgerForge should understand how money moves between financial entities owned by the user rather than treating every transaction independently.

A salary may move through multiple accounts before funding investments or paying liabilities. These intermediate transfers should be recognised as movement of existing assets rather than new income or expenses.

Financial intelligence must always remain:

- Deterministic
- Explainable
- Auditable
- Reproducible

Every automated conclusion must be traceable back to its supporting financial evidence.
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

LedgerForge should become the trusted personal financial operating system that users open every day because it provides the clearest, most accurate understanding of their financial life.

Importing documents should become an almost invisible maintenance activity while repository-backed dashboards evolve into a living financial operating system that continuously reflects a user's complete financial position.

LedgerForge should progressively evolve from historical financial record keeping into intelligent financial planning and decision support while remaining offline-first and preserving financial truth.

The application should ultimately help answer questions such as:

- Where did my money come from?
- Where did it go?
- What merely moved between my own accounts?
- What changed my net worth?
- What should I do next?

Future capabilities such as salary planning, retirement tracking, investment analysis and financial forecasting should reinforce this vision without compromising explainability, determinism or user trust.

Every future feature should reinforce the core mission by reducing manual work, increasing confidence and preserving financial truth.

Every future capability should reinforce the core mission of reducing manual work, increasing confidence, preserving financial truth and helping the user understand—not merely record—their financial life.

LedgerForge should always favour deterministic financial understanding over opaque statistical inference or black-box AI, ensuring every insight remains explainable, reproducible and worthy of the user's trust.
