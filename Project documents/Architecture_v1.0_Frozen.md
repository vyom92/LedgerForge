# LedgerForge Architecture v1.0 (Frozen)

**Status:** Frozen v1.0 baseline, status-aligned through accepted ADR-032 and verified Sprint 42 implementation.

This document is the architectural baseline for LedgerForge v1.0. It remains frozen except for status-alignment updates required to reflect completed implementation milestones and approved ADRs.

## Implementation Status Boundary

- Production import support is verified only for the approved Axis Bank NRE CSV layout.
- PDF text extraction, institution detection, statement classification and parser selection are implemented foundations, not production PDF statement support.
- The password-provider contract and locked-PDF reader interface exist; no production credential source, password-entry workflow or Keychain integration exists.
- XLS, XLSX, TXT and OCR remain planned.
- The parser registry does not provide production HDFC bank-account, CBQ bank-account, CBQ credit-card, American Express credit-card, Axis credit-card or broader Axis account-layout coverage.
- Parser-owned verified Axis account identifiers and deterministic confirmed-import account resolution are integrated, but arbitrary multi-institution, multi-layout and cross-format identity support remains planned.

This status note does not alter the frozen architecture or imply support from the presence of a protocol, model, reader or fixture alone.

## Vision

LedgerForge is an offline-first personal financial operating system that automatically consolidates financial information into a single trustworthy dashboard. Document import is an enabling capability, not the primary product. Every feature should either reduce manual work, increase confidence, or surface meaningful financial insight.

## Core Principles

- Offline first.
- Single source of truth.
- Every monetary value carries its currency.
- Native currency is always preserved.
- Currency conversion is derived, never destructive.
- Financial values must be consistently formatted according to their locale.
- Every imported value must be traceable.
- Readers know file formats.
- Readers produce RawDocument and never perform financial interpretation.
- Passwords are resolved by the import coordination layer and supplied to readers when required.
- Parsers know institutions and document families.
- Rules know business meaning.
- Plugin parser architecture.
- Every commit should build successfully.
- Dashboard first. Import second.
- Automation over manual maintenance.
- Financial intelligence should always be explainable.
- Learn statement formats instead of hardcoding institutions whenever practical.
- Every successful import should improve the system.
- Approved reference fixtures define financial truth across equivalent document formats.
- Preserve user trust through deterministic processing and full auditability.

## Design Philosophy

LedgerForge is a financial dashboard first.

Importing documents is infrastructure, not the primary experience.

Every subsystem should ultimately improve one of three things:

- Understanding.
- Confidence.
- Automation.

If a feature does not improve at least one of these, it should be reconsidered.

## Import Pipeline

ImportCoordinator
→ PasswordProvider
→ ReaderRegistry
→ Reader (production CSV; PDF foundation; future XLS / XLSX / TXT)
→ RawDocument
→ Institution Detection
→ Statement Classification
→ Parser Selection
→ Statement Parser
→ FinancialDocument
→ Validation
→ Fingerprinting & Duplicate Detection
→ Repository Persistence Boundary
→ Repositories
→ SQLite
→ RepositoryStoreHydrator
→ Runtime Stores
→ ViewModels
→ Financial Dashboard

### Pipeline Principles

- ImportCoordinator owns import orchestration.
- PasswordProvider resolves optional passwords before reader execution.
- ReaderRegistry selects the appropriate reader for the requested file format.
- Readers understand file formats only.
- Readers produce RawDocument.
- Readers never perform financial interpretation.
- Readers never access Keychain, UI prompts or password policy directly.
- Institution Detection identifies the originating institution using extracted document content.
- Statement Classification determines the document family (Bank, Credit Card, Brokerage, Salary, Insurance, etc.).
- Parser Selection chooses the correct parser implementation.
- Statement Parsers construct FinancialDocument as the canonical parser output.
- Validation is the only stage permitted to verify financial correctness.
- Fingerprinting & Duplicate Detection executes only after successful validation.
- Duplicate detection must remain deterministic, explainable and auditable.
- Repository protocols form the persistence boundary.
- SQLite remains an implementation detail behind repository abstractions.
- Repository persistence updates runtime stores only after validated writes complete successfully through RepositoryStoreHydrator.
- RepositoryStoreHydrator is the only approved persistence-to-runtime boundary.
- Stores expose validated runtime state to the UI.
- Rules Engine enriches validated financial data but never alters imported financial truth.
- Every supported file format converges into the same deterministic pipeline before parser execution.
- Equivalent reference fixtures across CSV, PDF and future formats must preserve identical observable financial truth.

## Core Domain

- Account (central entity)
- Transaction
- Security
- Holding
- ImportSession
- ImportProfile
- Rule
- Category
- DocumentMetadata
- RawDocument
- FinancialDocument
- StatementClassification
- TransactionStore
- Money
- ExchangeRate
- WorkspaceSettings
- AccountStore

## Long-Term Product Modules

- Dashboard
- Accounts
- Investments
- Budget & Cash Flow
- Documents
- Rules & Automation
- Financial Intelligence
- Financial Health
- Goals
- Universal Search
- Import Studio
- Financial Timeline
- Multi-Currency Dashboard
- Exchange Rates

## Target Document Families

These are architecture compatibility targets, not current production parser coverage.

- Bank Accounts
- Credit Cards
- Brokerage
- Salary
- Tax
- Mutual Funds
- Government Records

## Milestones

- Milestone M1: Statement Import Foundation ✅ (production support remains limited to the approved Axis Bank NRE CSV layout)
- Milestone M2: Statement Understanding ✅
- Milestone M3: Canonical Financial Handoff ✅
- Milestone M4: FinancialDocument-native Parsing ✅
- Milestone M5: Validation Pipeline Refinement ✅
- Milestone M6: Repository & Data Platform ✅
- Milestone M7: Dashboard Experience (Foundation Complete) ✅
- Milestone M8: Insights & Analytics
- Milestone M9: Financial Ecosystem

## North Star

LedgerForge should become the trusted personal financial operating system that users open to understand their financial life. Imports, future OCR, parsers and profile learning exist to keep financial information accurate and current with minimal manual effort. The dashboard and insights remain the primary experience.

### Success Criteria

LedgerForge succeeds when users spend less time maintaining financial records and more time making financial decisions.

The application should quietly maintain an accurate financial model while presenting meaningful insights through a clean dashboard.

Financial calculations must remain deterministic, explainable and consistent across institutions, currencies and future investment modules.

## Compatibility Review

These institutions and document families are design-review targets. Listing them does not establish production parser support.

Every architectural decision should be reviewed against:

- Axis Bank Account
- Axis Credit Card
- HDFC Bank Account
- CBQ Bank Account
- CBQ Credit Card
- American Express Credit Card
- IBKR
- Salary Slip
- Mutual Fund CAS
- AIS / Form 16

Each target family requires its own approved fixture and financial baseline. Listing a target is not production support and one supported family never implies full institution support.

## Currency Architecture

LedgerForge is designed as a multi-currency financial operating system.

Principles:

- Every monetary value retains its native currency.
- Exchange rates are versioned and auditable.
- Historical reports may use historical exchange rates.
- Users may configure a base currency plus additional display currencies.
- Dashboard metrics should support simultaneous presentation in multiple currencies.
- Currency formatting follows regional conventions (for example, Indian digit grouping for INR and international grouping for USD/QAR).

## Future Architecture (v1.1+)

The following concepts are intentionally excluded from Architecture v1.0 but are planned for future milestones:

- XLS/XLSX Reader
- OCR fallback for scanned documents
- Statement Learning Mode
- Profile Library
- AI-assisted Column Detection
- Generic Rules Engine v2
- Financial Intelligence Engine
- Financial Replay
- Predictive Cash Flow

These features must evolve without violating the core principles defined in this document.

## Architecture Freeze

No major architectural changes to the v1.0 baseline unless:

1. A real financial document exposes a fundamental design flaw.
2. The change benefits multiple document families.
3. The change preserves the core architecture principles.

Future enhancements will be tracked under Architecture v1.1.
