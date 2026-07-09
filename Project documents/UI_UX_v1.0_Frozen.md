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
## Design Authority

The UI specification is governed by the following hierarchy:

1. UI_UX_v1.0_Frozen.md
2. Project documents/UI Assets/Approved/DesignBoard_v2.0.png
3. Remaining Approved UI Assets
4. SwiftUI Implementation

If a conflict exists, items higher in the hierarchy take precedence.

SwiftUI implementation is considered a translation of this specification rather than the source of truth.

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
# Approved Visual Direction

LedgerForge adopts a Deep Indigo desktop design language.

Visual characteristics:

- Dark Mode first
- Deep indigo gradient workspace
- Slate glass-style cards
- Purple / blue primary accents
- High-contrast white typography
- Green for positive financial values
- Red / orange for negative financial values
- Amber for warnings
- Dense financial dashboards
- Native macOS interaction patterns

Implementation sprints must not redesign this visual language.

Implementation sprints translate this approved visual language into SwiftUI.

Visual refinements require updates to the approved assets before implementation.

Implementation must never become the source of truth for design.

All future screens inherit these visual tokens unless a newer frozen specification supersedes them.

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

`Project documents/UI Assets/Approved/DesignBoard_v2.0.png` is the master visual reference for LedgerForge.

DesignBoard_v2.0 defines:

- application shell
- visual language
- spacing
- navigation
- information hierarchy
- component relationships

Individual screen assets inherit from this master reference.

The approved master visual specification is:

Project documents/UI Assets/Approved/DesignBoard_v2.0.png

Individual approved assets within the same folder define the implementation details for each screen while remaining consistent with the master DesignBoard.

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

The Design System is defined by:

Project documents/UI Assets/Approved/DesignSystem_v1.0.png

The Design System derives from DesignBoard_v2.0 and defines reusable implementation tokens.

Individual screen assets inherit from the DesignBoard and consume this shared design system.

Design principles:

- 8pt spacing grid
- SF Pro typography
- Glass-like slate cards
- Deep Indigo theme
- Consistent elevation
- Native macOS controls
- Thin separators
- Rounded corners
- Minimal shadows
- Financial-first information hierarchy

All new components inherit this design system.

No component should introduce new visual styles independently.

---

# Screen Inventory

Version 1.0 defines the approved implementation targets:

- Dashboard
- Accounts
- Transactions
- Imports
- Settings

Future screens:

- Insights
- Budgets
- Reports
- Investments
- Financial Timeline
- Financial Intelligence
- Rules & Automation

---

# Component Library

## Navigation

- Navigation Sidebar
- Toolbar

## Financial Components

- Financial KPI Card
- Account Card
- Transaction Table
- Import Activity Card

## Input Components

- Search Bar
- Filter Chips
- Import Wizard

## Status Components

- Status Badge
- Validation Banner

## Developer

- Developer Console

---

# Visual Rules

Comfortable but information-dense spacing.

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

Dark Mode is the primary design target.

Light Mode may be supported in a future design revision but is not part of the current frozen implementation target.

VoiceOver compatible.

Accessibility is considered a release requirement rather than a post-release enhancement.

Every primary interaction should be fully keyboard accessible.

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
# Design Tokens

The following visual tokens are considered globally consistent.

Theme

- Deep Indigo

Typography

- SF Pro

Corner Radius

- Standard
- Large

Spacing

- 8pt base grid

Animation

- Fast
- Subtle

Elevation

- Four defined surface levels

Icons

- SF Symbols style
- Outline preferred

Charts

- Smooth lines
- Minimal gradients

Tables

- Compact
- Financial-first

Numbers

- Right aligned
- Tabular figures

# Approved UI Assets

The following assets form the approved UI specification.

Project documents/UI Assets/Approved/

- DesignBoard_v2.0.png (Master reference)
- Dashboard_v1.0.png
- Accounts_v1.0.png
- Transactions_v1.0.png
- ImportWizard_v1.0.png
- Settings_v1.0.png
- DeveloperConsole_v1.0.png
- DesignSystem_v1.0.png
- UserJourney_v1.0.png
- ComponentLibrary_v1.0.png
- AppIcon_v1.0.png (Approved app icon reference)

DesignBoard_v2.0 defines the overall application and is the master UI reference.

The remaining assets define approved screen implementations and supporting design systems. Implementation sprints must translate these approved assets into SwiftUI rather than redesigning the UI during implementation.

# Acceptance Criteria

Implementation is complete when:

✓ Navigation matches this specification.

✓ Dashboard matches Dashboard_v1.0.png and remains consistent with DesignBoard_v2.0.png.

✓ Preview exists only during import.

✓ Developer Console is hidden by default.

✓ Sidebar remains permanent.

✓ Components are reusable.

✓ No implementation introduces UI redesign.

✓ New screens extend this architecture rather than replacing it.

✓ All approved UI assets exist under Project documents/UI Assets/Approved/.

✓ DesignBoard_v2.0 remains the master reference.

✓ Every implemented screen has a corresponding approved asset.
✓ Implementation matches the approved assets without introducing unapproved visual language.

✓ DesignBoard_v2.0 remains the master visual authority throughout implementation.
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

The approved UI assets are the authoritative visual specification.

If implementation differs from the approved assets, the assets take precedence unless a newer frozen design revision has been approved.

DesignBoard_v2.0 should be revised before individual screen assets whenever a change affects the overall application structure or visual language.

Minor refinements may update individual assets without requiring a new DesignBoard revision, provided the master design language remains unchanged.

Workflow v2.1 requires implementation planning to reference this document and the approved UI assets before UI changes are made.

Architecture, Product Vision and this document together define the approved implementation boundary for all future UI work.
