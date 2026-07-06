# LedgerForge – GitHub Copilot Instructions

## Project Identity

LedgerForge is an offline-first personal financial operating system.

The application exists to provide an accurate, explainable and trustworthy financial dashboard.

Document import, parsing, OCR and automation exist only to keep the financial model accurate.

---

# Engineering Philosophy

Always prefer:

1. Financial correctness
2. Trust
3. Simplicity
4. Maintainability
5. Automation
6. Visual polish

Never sacrifice correctness for convenience.

---

# Before Writing Code

Read these project documents before making architectural changes:

- ADR.md
- Architecture.md
- Product Vision.md
- Engineering Standards.md

Treat these documents as the source of truth.

---

# Architecture Rules

Use MVVM.

Views:
- Presentation only.
- No business logic.
- No parsing.
- No persistence.

ViewModels:
- Observe Stores.
- Prepare presentation models.

Stores:
- Own application state.

Ownership:

- DocumentStore owns imported documents and transactions.
- AccountStore owns accounts.
- ImportSession records imports.
- Views never coordinate workflows.

---

# Financial Rules

Always preserve imported financial truth.

Never overwrite imported values.

Native currency is always preserved.

Currency conversion is presentation only.

Every financial calculation should remain deterministic and explainable.

Support multiple currencies.

Do not assume INR is the only currency.

---

# Import Pipeline

Financial Document

↓

Reader (PDF / CSV / XLS / XLSX / TXT)

↓

FinancialDocument

↓

Institution Detection

↓

Document Classification

↓

Parser Selection

↓

Statement Parser

↓

Validation

↓

Import Session

↓

TransactionStore

↓

AccountStore

↓

DashboardViewModel

↓

Views

Rules:

- Readers extract data only.
- Readers never perform business logic.
- Parsers never know the original file format.
- All supported formats must converge into the same FinancialDocument model.
- Validation always occurs before stores are updated.
- TransactionStore owns transactions.
- AccountStore owns accounts.
- Views consume ViewModels only.

Do not bypass validation.

---

# Reference First

Never invent:

- statement layouts
- dashboard layouts
- user workflows
- financial reports
- UI designs

Always use existing project references.

If sufficient references do not exist, stop and ask for them.

---

# Coding Standards

Keep functions small.

Prefer composition over inheritance.

Avoid duplicate logic.

Use descriptive names.

Avoid force unwraps.

Do not introduce unnecessary abstractions.

---

# Multi-file Changes

Before editing:

Understand the entire workflow.

Minimize the number of edited files.

Preserve existing behaviour unless explicitly requested.

---

# Editing Existing Files

Before modifying a file:

Verify the filename in the header comment matches the intended file.

If it does not match:

Stop.

Do not continue editing.

---

# Financial Models

Prefer domain models over primitive values.

Future preferred types include:

- Money
- ExchangeRate
- Account
- ImportSession

Avoid spreading Decimal calculations throughout the UI.

---

# Dashboard

The Dashboard is the product.

Imports exist to support the Dashboard.

Always optimise for a trustworthy financial overview.

---

# Parser Rules

Do not hardcode institution-specific logic unless inside that institution's parser.

Generic logic belongs in shared components.

Institution-specific behaviour belongs only inside the corresponding parser.

---

# Testing

Build after every logical change.

Preserve existing parser behaviour.

Do not introduce regressions.

When possible, validate changes against known reference statements.

---

# AI Behaviour

Do not invent requirements.

Do not invent financial rules.

Do not invent document formats.

Do not invent UI.

If requirements are ambiguous, ask.

Accuracy is more important than speed.
