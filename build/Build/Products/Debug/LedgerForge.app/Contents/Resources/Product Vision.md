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

---

# Core Experience

LedgerForge should feel like a financial command center rather than an importer.

Primary modules:

- Dashboard
- Multi-Currency Dashboard
- Accounts
- Investments
- Budget & Cash Flow
- Documents
- Import History
- Rules & Automation
- Financial Intelligence
- Financial Timeline
- Settings

---

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

1. Identify the financial institution.
2. Determine the document type (bank account, credit card, investment, salary, etc.).
3. Unlock encrypted documents automatically using the institution's stored password when available.
4. Extract raw document contents into a normalized internal representation.
5. Detect the document layout and version.
6. Apply the appropriate parser.
7. Validate the extracted financial data.
8. Update LedgerForge stores only after validation succeeds.

Institution detection should rely on document fingerprints, metadata, recurring keywords, visual structure, and previous successful imports rather than filenames.

Statement layouts may evolve over time. LedgerForge should automatically recognize new layouts, preserve compatibility with older formats, and learn from successful imports without compromising deterministic parsing.

The parsing engine should be format-independent. Whether data originates from PDF, CSV, XLS/XLSX or TXT, downstream components should receive the same normalized transaction model.

Importing documents should require little or no user interaction beyond selecting the file.
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

LedgerForge should become the trusted financial operating system that users open every day because it provides the clearest, most accurate understanding of their financial life. Importing documents becomes an invisible maintenance task while the dashboard evolves into a living representation of accounts, investments, budgets, cash flow and long-term financial progress.
