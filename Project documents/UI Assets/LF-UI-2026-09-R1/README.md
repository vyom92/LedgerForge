# LF-UI-2026-09-R1

Approved visual direction and canonical written contracts for the private personal app. Publication does not select a sprint or establish native acceptance; implementation status below links to separately accepted outcomes. Order inherits [Guide rule H](../../Project_Guide.md#documentation-order): revision, then natural screen ID/suffix; machine payload paths are deterministic. [Current product state](../../PROJECT_STATE.md) and [scope decisions](../../SCOPE_DECISIONS.md) control applicability.

## Canonical inputs

| Input | Responsibility / status |
| --- | --- |
| [DESIGN_HANDOFF](DESIGN_HANDOFF.md) | Shared design and component requirements, artwork/caption exceptions |
| [DESIGN_TOKENS](DESIGN_TOKENS.json) | Named reference roles; numeric and palette values unchanged; appearance applicability updated by the 2026-09-14 owner decision |
| [SC-01_App_Shell](SC-01_App_Shell.md) | Canonical shell/navigation text relocated from approved handoff |
| [SC-02_Transactions](SC-02_Transactions.md) | Canonical Transactions text relocated from approved handoff |
| [SC-03_Dashboard](SC-03_Dashboard.md) | Canonical Dashboard text relocated from approved handoff |
| [Inherited_Screens](Inherited_Screens.md) | Simple appearance plus inherited accepted screen contracts from frozen UI |
| [MasterBoard](MasterBoard_LF-UI-2026-09-R1.png) | Approved unchanged collage; embedded “v2.0” is a design label only |
| [ACCEPTANCE](ACCEPTANCE.md) | Required checks, not invented pass evidence |
| [SOURCES](SOURCES.md) | Provenance and historical source refs |
| [ASSET_MANIFEST](ASSET_MANIFEST.json) | Payload hashes/sizes; manifest excludes itself |
| [SC-05A](LF-UI-2026-09-R1_SC-05A_Cross_Screen_Conformance_Matrix.md) | Coordinator-accepted cross-screen audit to refresh before Sprint 92 |

These new screen files reorganize already approved written text; they are not new designs or approval of local drafts. [UI/UX](../../UI_UX_v1.0_Frozen.md) owns shared interface architecture.

## Supporting and draft material

The tracked `LF-UI-2026-09-R1_SC-01_App_Shell_Visual_Contract.md` and `LF-UI-2026-09-R1_SC-02_Transactions_Visual_Spec.md` remain **draft/supporting specifications**, not competing canonical owners. Their status is unchanged by this restructure.

All current SC images in this R1 folder are **owner-curated / Chat-approved / published design references**. Their exact current bytes are listed in ASSET_MANIFEST.json. Apply the [responsibility-based authority](DESIGN_HANDOFF.md#authority): approved references control appearance/composition, written financial/workflow rules control meaning, state/responsive sheets control their conditions, and numeric tokens control named roles. Publication does not itself implement or accept a native screen.

SC-01/SC-02 informed accepted Sprint 89. **SC-03 A/B/C: OWNER-CURATED / CHAT-APPROVED / PUBLISHED; SPRINT-90 DATA/BEHAVIOR AND SPRINT-91A CURRENT VISUAL FOUNDATION ACCEPTED.** The [Sprint-90 outcome](../../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-90) remains intact. The owner accepts the accumulated [Sprint-91A outcome](../../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a), including current Dashboard composition and dark-only local customizable appearance with responsive Settings. **SC-04 A/B/C: OWNER-CURATED / CHAT-APPROVED / PUBLISHED, BYTES UNCHANGED.** Their System/Light plan is superseded history under the [owner decision](../../SCOPE_DECISIONS.md#dark-appearance-decision). Final-byte small-window rechecking remains explicitly incomplete and accepted as a limitation; earlier r34 evidence is not a final-byte PASS. SC-05A must be refreshed against published 91A before Sprint-92 execution; its original Keep classifications are historical, not blanket native evidence. Sprint 92 is NEXT / NOT STARTED.

The current reference inventory, in natural screen order:

- SC-01 App Shell Supporting Reference;
- SC-01 App Shell Visual Contract;
- SC-02A Transactions Wide Reference;
- SC-02B Transactions Narrow Responsive Reference;
- SC-02C Transactions State Component Contract;
- SC-03A Dashboard Wide Reference;
- SC-03B Dashboard Narrow Responsive Reference;
- SC-03C Dashboard State Component Contract;
- SC-04A Appearance Settings Reference;
- SC-04B Appearance Light/Dark Surface Comparison;
- 04C Appearance State Component Contract.

The named SC images retain their existing filenames; the extensionless `04C_Appearance_State_Component_Contract` remains published as-is. Their presence is not a native pass. Keep every PNG intact; [exact ignored caption portions](DESIGN_HANDOFF.md#ignored-caption-portions) apply to SC-02A/02C/03B only. Do not regenerate/delete images to remove superseded text. [Archived visuals](../Archived) remain historical references. The owner intentionally deleted `UserJourney_v1.0.png`; preserve its deletion. All retained archived images and approved R1 PNG payloads remain unchanged. `AppIcon_v1.0.png` supplies the accepted application/sidebar identity; the archived original remains intact.

The [Import Preview alternatives and remaining R1 questions](../../Work%20notes/Transaction_and_R1_workflows.md) are unaccepted work notes, not approved screen replacements. ASSET_MANIFEST.json inventories every current non-metadata R1 payload file; private originals and Finder metadata are not package payloads.
