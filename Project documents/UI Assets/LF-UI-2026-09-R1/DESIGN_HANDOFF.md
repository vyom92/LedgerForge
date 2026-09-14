# R1 shared design handoff

**Revision:** LF-UI-2026-09-R1. Approved visual direction and written design specification; native implementation/acceptance remains separate. [README](README.md) owns the package map; [SOURCES](SOURCES.md) owns provenance and historical preparation refs. Inventory order inherits [Guide rule H](../../Project_Guide.md#documentation-order).

## Authority

Authority is resolved by responsibility. Explicit owner decisions and accepted financial/workflow/architecture rules control meaning. Approved visual references control appearance and composition. Responsive and state sheets control their specific reflow, data-state and interaction conditions. Numeric tokens control named size, spacing and typography roles. Written screen contracts supply semantic detail and the explicit exceptions below; they do not demote approved visual references to optional decoration. Record a concrete conflict instead of choosing whichever source best matches existing code.

SC-01's visual contract controls shell/navigation direction; its supporting artwork is supplementary. SC-03A controls Dashboard composition, emphasis and material direction; SC-03B controls constrained reflow; SC-03C controls truthful states and interactive versus display-only components. A schematic state sheet does not replace the glossy wide reference's aesthetic, and a PNG cannot authorize invented financial values or new actions. The collage's “v2.0” is a design label, not an app release. Numeric roles are specified targets, not measurements of illustrative collage pixels. The [accepted Sprint-91A outcome](../../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a) now includes the current Dashboard visual foundation and dark appearance, with the explicit final-byte small-window limitation. The [earlier qualification](../../Work%20notes/Transaction_and_R1_workflows.md#sprint-91a-visual-conformance) remains history.

[Scope decisions](../../SCOPE_DECISIONS.md) owns rejected formal accessibility work and the exact [2026-09-14 owner decision](../../SCOPE_DECISIONS.md#dark-appearance-decision) reopening bounded local appearance controls. Keep practical readability, full Money/currency, keyboard interaction, focus distinct from selection, names/tooltips, native rendering and responsive content fit. Preserve image bytes and apply only the exact written caption exceptions below. Legitimate local/ChatGPT inspection is allowed; no private original/credential/financial source content enters Git or becomes a manufactured statement input.

## Canonical screen routing

| Screen | Written owner |
| --- | --- |
| SC-01 shell/navigation/responsive hierarchy | [SC-01_App_Shell](SC-01_App_Shell.md) |
| SC-02 Transactions/filter/sort/inspector/totals | [SC-02_Transactions](SC-02_Transactions.md) |
| SC-03 Dashboard/native-currency hierarchy | [SC-03_Dashboard](SC-03_Dashboard.md) |
| Simple appearance and inherited Accounts/Import/Preview/Salary/Settings/Developer Console | [Inherited_Screens](Inherited_Screens.md) |

## Readable text and layout

Use shared roles rather than local per-view substitutions. Reference defaults include 16-point body text and a 12-point caption target; existing compact native form roles retain their approved defaults. The owner-authorized hierarchy sliders may override those defaults. Rendered fonts and AppKit measurements must share the same family, size, weight and tabular-digit features. Rows grow/reflow for the chosen role; window width never changes saved typography. No density, tracking or weight editor is authorized.

Full amounts, minus signs, currency context and fractional digits must remain readable. Never wrap an amount, truncate it, display an unexplained abbreviation, or shrink it until it fits. Reallocate width, reflow the group or allow scrolling instead.

## 2. Shared design system and components

### 2.1 Appearance system

**Accepted implementation boundary — 2026-09-14:** [2026-09-14 owner decision](../../SCOPE_DECISIONS.md#dark-appearance-decision) authorizes dark-only shared colour/tint wells, one installed-font family selector, hierarchy-size sliders and background/card tint opacity in the existing responsive Settings destination. Changes apply immediately through one local appearance store and the existing LFTheme environment. Initial/reset values preserve the accepted factory defaults; reset clears only appearance overrides. The owner’s newer saved choices are separate local user state and must not be reset or promoted into defaults during closure. Financial/status meanings remain unchanged.

The former Follow System/Light/Dark and optional-preset plan is superseded history, preserved in [Inherited Screens](Inherited_Screens.md#5-simple-local-appearance). It is not a second feature still to build. Reference palettes are design inputs, not a runtime loader or a reason to replace current approved colours. See the [accepted Sprint-91A outcome](../../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a) for native evidence and accepted limitations; the [work note](../../Work%20notes/Transaction_and_R1_workflows.md#sprint-91a-dark-appearance) preserves earlier checkpoints.

Use semantic roles: background, surface, raised surface, primary/secondary text, control border, separator, accent, focus, selected surface and semantic status text. Do not scatter arbitrary colours through screens. Accent is not a substitute for success/error semantics. A negative number is not automatically a problem and a credit is not automatically income.

The token file records a small consistent spacing/radius scale, typography, minimum control sizes, row minima, column widths and responsive policies. Sizes are minima or defaults where labelled, not rigid constraints that can crop larger text.

Use restrained native material depth in navigation, toolbar and appropriate controls. Liquid Glass belongs to appropriate navigation/control surfaces; standard material or substantially opaque surfaces keep financial content readable. Text and Money stay crisp and opaque. An alpha-tinted colour alone does not satisfy the material role. Inspect the complete layer stack and remove fills that conceal native effects; the result must work on the owner's real desktop without a staged wallpaper or changed system preference. Do not apply glass to every balance card, layer competing bordered boxes, or recolour financial values with the Indigo accent.

### 2.2 Components and states

| Component | Required interaction and state contract |
|---|---|
| Sidebar row | Label plus icon; selected state is explicit; keyboard focus remains distinguishable from selection. |
| Primary/secondary buttons | Clear action text, ordinary keyboard focus, visible pressed/disabled state. One dominant action per task region. |
| Search field | One main search per transaction workspace; clear control; search scope stated; no duplicated global/local searches without different implemented purposes. |
| Filter control/chip | Shows selection and count; removable; access is preserved when collapsed. |
| Table | Sortable/resizable supported columns; right-aligned tabular amounts; readable selection; row access by keyboard. |
| Inspector | Selected-record details; close control; stable record identity; unavailable provenance is not inferred. |
| Metric | Label, native-currency context, value and time/coverage context where available. Missing evidence is distinct from zero. |
| Money input | Natural exact user entry; deterministic validation and formatting; persisted Money validation is not weakened. |
| Feedback | Field-specific errors, meaningful empty/loading states and bounded recovery; no green “success” before durable acceptance. |

Check selected, focus, hover, pressed, disabled, loading, empty, no-matches, unavailable and error states. Keep transitions brief and purposeful; do not animate financial values in ways that obscure their meaning.

A successful import validation badge is not the same as a cleared or reconciled transaction. Prefer contextual validation information in the inspector, with prominent row attention only where an authoritative actionable state exists. Do not invent a new transaction-review status model to support a badge.

### 2.3 Ordinary owner usability

Keep useful keyboard paths, meaningful native control names, visible focus and distinct selection. Financial values, currency context and consequential states remain readable and cannot rely on colour alone. Verify no clipping, usable resizing, reachable actions and understandable feedback in the actual owner workflow. No VoiceOver campaign, Full Keyboard Access qualification, reduced-transparency programme, contrast certification or separate accessibility release gate is required.

## 6. Exact visual exceptions and inherited screens

The approved PNG remains intact as the visual reference. These limitations are explicit, not a new unapproved redraw:

| Artwork element | Implementation treatment |
|---|---|
| “v2.0” | Design-image label only; use LF-UI-2026-09-R1 to identify this handoff; do not change app version. |
| Greetings/profile chrome | Not required; keep the ordinary Dashboard title and omit static personal/workspace decoration. |
| Insights/Budgets/Reports/Investments/Soon | Omit until approved, functional, repository-backed destinations exist. |
| Add Transaction, arbitrary export, notes/splits/tags/attachments | Not authorized by this image; preserve only implemented separately approved actions. |
| Charts, percentages, sample totals and historical dates | Illustrative pixels, never financial fixtures, expected values, product facts or an independent oracle. |
| “Cleared”, salary receipt and bank/payroll association | Use only proven meanings. Import validation is not bank clearing; payroll is not bank receipt. |
| Raw identifiers and source filenames | Retain applicable privacy rules; the disposable screenshot decision does not override repository policy. |
| Always-visible Developer Console | Retain current developer/build gating. |
| Tight mobile-looking narrow table | Treat as compact composition guidance; native macOS keyboard, account and currency context remain required. |
| Appearance controls in SC-04 | The 2026-09-14 owner scope authorizes dark shared colour/tint wells, family/size sliders and surface-opacity controls. System/Light, density, weight/tracking, Preview/Apply/Cancel, sync and portable themes remain outside this implementation. Preserve artwork bytes and use the current written scope for controls. |
| Optional numeric alignment | Tabular amount alignment is mandatory. |
| Multiple visible logos | No icon or branding replacement is authorized; retain the existing app asset until separately selected. |

<a id="ignored-caption-portions"></a>
### Retained local references: caption exceptions — 2026-09-11

The user explicitly requires preserving the design while ignoring the rejected acceptance portions. The following PNGs remain unchanged, owner-curated, Chat-approved and published visual references. Their VoiceOver/formal-accessibility captions do not create work, dependencies or acceptance gates. Ordinary keyboard use, readable full Money/currency, resizing, selection and focus remain subject to the bounded native checks above. Publication is not a passed native-app test.

| Local filename | Specific caption portion to ignore |
|---|---|
| `LF-UI-2026-09-R1_SC-02A_Transactions_Wide_Reference.png` | The bottom caption's “VoiceOver reads full Money and currency” requirement. Full readable Money and currency remain required. |
| `LF-UI-2026-09-R1_SC-02C_Transactions_State_Component_Contract.png` | The bottom Keyboard & accessibility caption's “VoiceOver receives full Money and currency” requirement. Keep the valid component states and ordinary keyboard guidance. |
| `LF-UI-2026-09-R1_SC-03B_Dashboard_Narrow_Responsive_Reference.png` | The “VoiceOver” and formal qualification portions of “Native keyboard, VoiceOver and material checks remain pending.” Actual keyboard usability and readable native rendering still require applicable evidence. |

No PNG regeneration is required for this reset. This written exception is the controlling disposition for the affected captions.

The collage is 1536 × 1024 pixels and contains small embedded panels. It is **not** five independently rendered, full-size pixel-perfect screens, an editable native prototype or a complete component-state sheet. This written contract supplies details absent from the image. Do not claim missing renders or native interaction tests exist.

Accounts, Import, Salary and Developer Console inherit the common system while retaining their accepted behaviour. Accounts needs readable identity distinctions. Import needs coherent per-task completion/empty states, not a new queue in this task. Salary needs only later bounded refinement. Developer Console preserves typed diagnostics and clear active-profile versus selected-target labels.

## Acceptance and unresolved proposals

[ACCEPTANCE](ACCEPTANCE.md) owns required native/financial/interaction checks; written design approval is not a pass. Current native behavior, mixed bank/card mapping and the reported INR-colour observation need the exact implementation evidence. No screenshot proves a financial defect. Pure design docs do not authorize query, filter, preference or product changes.

The owner's Import Preview layout feedback and wide-right/full-width alternatives are retained only as [unaccepted work-note evidence](../../Work%20notes/Transaction_and_R1_workflows.md#packet-import-preview-responsive-placement). They are not part of this canonical shared contract. The exact Sprint-89 algorithm/native procedure lives in that same note, under its paused/unaccepted status.
