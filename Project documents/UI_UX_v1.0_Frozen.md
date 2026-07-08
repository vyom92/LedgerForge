# LedgerForge UI/UX v1.0 Frozen

Version: 1.0

Status: FROZEN

Purpose:
This document defines the visual architecture, interaction model and design language of LedgerForge.

## Relationship to Other Documents

This document is the visual equivalent of `Architecture_v1.0_Frozen.md`.

- Product Vision defines what LedgerForge should become.
- Architecture defines how LedgerForge is engineered.
- This document defines how LedgerForge should look and behave.

Implementation sprints must implement this specification rather than redesigning it.

Like Architecture_v1.0_Frozen.md, this document is intended to minimise design drift during implementation.

The objective is that implementation sprints translate this specification into SwiftUI components rather than redesigning the application.

---

# Core Principles

LedgerForge is a desktop financial application.

It is not:

- a spreadsheet
- a developer tool
- a database browser

The interface must prioritise:

1. Clarity
2. Information density
3. Speed
4. Predictability
5. Consistency

The backend architecture is already frozen.

The frontend should become equally stable.

---

# Design Philosophy

The application should feel closer to:

- Things
- Linear
- Apple Mail
- Xcode Navigator
- Arc Browser

and less like:

- Excel
- phpMyAdmin
- Internal developer tooling

Every screen should answer a user question.

Examples:

"What is my financial position?"

"What changed recently?"

"Where did my money go?"

"What imported successfully?"

---

# Application Shell

Frozen Layout

┌───────────────┬──────────────────────────────────────────────┐
│               │                                              │
│ Sidebar       │ Toolbar                                      │
│               ├──────────────────────────────────────────────┤
│               │                                              │
│               │                                              │
│               │ Main Content                                │
│               │                                              │
│               │                                              │
│               │                                              │
│               │                                              │
└───────────────┴──────────────────────────────────────────────┘

Sidebar occupies approximately 20%.

Main content occupies approximately 80%.

The application shell is considered frozen. Future modules extend this shell rather than replacing it.

---

# Sidebar

Permanent.

Never hidden.

Contains navigation only.

Sections:

Dashboard

Accounts

Transactions

Imports

────────────

Insights

Budgets

Reports

────────────

Settings

Developer

The "Developer" section is hidden during normal operation unless Developer Mode is enabled.

---

# Toolbar

Contains only contextual controls.

Examples:

Date Range

Workspace

Filters

Import Statement

Search (where appropriate)

The toolbar changes based on the active page.

---

# Dashboard

Dashboard Sketch V3 is the visual reference.

The approved Dashboard Sketch V3 image should be stored under `Project documents/UI Assets/` and treated as the canonical visual reference for implementation.

Major sections:

Financial Snapshot

Accounts

Recent Transactions

Import Activity

Quick Actions

Future cards may be added without changing the overall layout.

---

# Accounts

Dedicated page.

Shows:

Institution

Account Type

Balance

Status

Supports future grouping.

No dashboard logic belongs here.

---

# Transactions

Dedicated page.

Contains:

Search

Filters

Transaction Table

Summary

Selection

Future transaction detail panel.

The dashboard should show only recent activity.

Full browsing belongs here.

---

# Imports

Dedicated page.

Shows:

Import History

Validation Results

Import Status

Imported Files

Errors

Warnings

This replaces "Recent Import" eventually living on the dashboard.

---

# Preview

Preview is NOT a permanent application page.

Preview belongs only to the import workflow.

Workflow:

Select File

↓

Preview

↓

Validation

↓

Import

↓

Dashboard

---

# Developer Console

Developer Console is NOT part of normal navigation.

Available only when Developer Mode is enabled.

Purpose:

Parser output

Repository logs

Validation diagnostics

Performance

Debugging

End users should never need to see it.

---

# Import Workflow

Frozen workflow.

Import Statement

↓

Choose File

↓

Preview

↓

Validation

↓

Confirm

↓

Import

↓

Dashboard Refresh

---

# Design System

Rounded cards.

Consistent spacing.

Consistent typography.

Single accent colour.

Minimal borders.

Information hierarchy over decoration.

Animations should be subtle.

Spacing should follow a consistent scale.
Typography should use native macOS text styles wherever practical.
Cards, buttons and tables should share a unified visual language.

---

# Screen Inventory

Version 1.0 defines the following primary screens:

- Dashboard
- Accounts
- Transactions
- Imports
- Settings

Future screens:

- Insights
- Budgets
- Reports

---

# Component Library

Reusable components only.

Navigation Sidebar

Toolbar

Financial KPI Card

Account Card

Transaction Table

Import Activity Card

Quick Action Card

Status Badge

Validation Banner

Search Bar

Filter Chips

Developer Console

Import Wizard

No duplicate implementations.

---

# Visual Rules

Large whitespace.

Readable tables.

Cards aligned to a grid.

No floating windows.

No nested scrolling where avoidable.

Consistent spacing throughout.

---

# Accessibility

Keyboard first.

Native macOS shortcuts.

Resizable layouts.

Dark Mode first.

Light Mode supported.

VoiceOver compatible.

---

# Future Modules

The following are intentionally excluded from v1.0:

Analytics

Budgets

Insights

Reports

Investments

Portfolio

Multi-currency

OCR

These will extend the frozen shell rather than redesign it.

---

# Acceptance Criteria

Implementation is complete when:

✓ Navigation matches this specification.

✓ Dashboard follows Dashboard Sketch V3.

✓ Preview exists only during import.

✓ Developer Console is hidden by default.

✓ Sidebar remains permanent.

✓ Components are reusable.

✓ No implementation introduces UI redesign.

✓ New screens extend this architecture rather than replacing it.

---

# Change Policy

Major UI changes require:

1. Proposal

2. Design Review

3. Mockup Update

4. Approval

5. Update to UI_UX_v1.x_Frozen.md

6. Visual approval.
7. Update any affected UI assets.

Implementation sprints translate the approved UI specification into SwiftUI components. Design decisions belong in this document, not in implementation sprints.
