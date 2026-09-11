# Rules and recurring

<a id="packet-first-rule-engine-decision-packet"></a>
<a id="packet-recurring-activity-evidence-packet"></a>

**Owners:** [FW-P2-21](../FUTURE_WORK.MD#fw-p2-21), [FW-P2-22](../FUTURE_WORK.MD#fw-p2-22), [FW-P2-23](../FUTURE_WORK.MD#fw-p2-23), [FW-P2-24](../FUTURE_WORK.MD#fw-p2-24), [FW-P2-25](../FUTURE_WORK.MD#fw-p2-25), [FW-P2-26](../FUTURE_WORK.MD#fw-p2-26), [FW-P2-27](../FUTURE_WORK.MD#fw-p2-27), [FW-P2-28](../FUTURE_WORK.MD#fw-p2-28), [FW-P2-29](../FUTURE_WORK.MD#fw-p2-29).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

How can reviewable suggestions help classification without changing source truth or overriding the owner?

## Current conclusion

UD-06 settles the product direction: **reviewable suggestions first; manual assignments win; disagreeing applicable rules return conflict/no proposal regardless of priority**. Include explanation and conflict handling in the first rule slice (FW-P2-21/22/23). This product decision does not accept a database or rule architecture.

Discovery found current manual assignments but no accepted rule/result/priority record. The proposed deterministic model needs explicit predicates, matching scope, rule identity/version and enablement, source snapshot/generation, result explanation and manual precedence. Dry-run proposals must not silently write assignments. A stale snapshot or multiple disagreeing matches cannot be resolved by choosing a convenient priority.

A manual correction may offer a rule proposal only for explicit review/confirmation; it is not automatic learning. Merchant aliases are derived user metadata and never overwrite imported description/payee/reference. Rules v2's compound conditions, priorities, dry runs, versioning and actions remain a later recorded scope; a mutating action needs its own ADR-037 contract.

Recurrence requires genuine duplicate-safe source history, identifiable occurrences, explainable cadence/tolerance and explicit owner confirmation. A recurring-looking amount or text is not an obligation, prediction or income/spend classification. Missed/extra events, source gaps, reversals and ambiguous matches must remain visible. Projections/obligations are separate from imported facts. Notifications need a selected trusted event, local policy and useful action, not a speculative alert catalogue.

## Evidence and references

Owner UD-06 recorded 2026-09-10; first/second-round repository evidence at `adcf83f52d309ddac18d95f0321d0c0f6120dd29` / `af2d1949c6e9a73af3bb004422b72882d28195e2`. Existing manual-category authority is accepted; first-rule and recurrence packets are proposals.

- [LedgerForgeTests/CategoryRepositoryTests.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/LedgerForgeTests/CategoryRepositoryTests.swift#L1); SHA-256 `3a5ecd33125ccff21b12b030e77865fab721677d9827ffd1bd65e28515c7a23f` — category repository contract tests
- [Services/CategoryManagementCoordinator.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Services/CategoryManagementCoordinator.swift#L117); SHA-256 `f43a45ec207ab9ceeeeb306f600956a4596b145bbf705b32a0a2c1bcbead5642` — CategoryManagementCoordinator.setCategory and mutate

## Unresolved decision or blocker

Chat must approve exact rule predicates, scope, versions, conflicts, persistence and genuine acceptance cases. Recurrence additionally lacks a selected authentic history and approved occurrence/obligation contract.

## What would invalidate this conclusion

Any silent overwrite of manual assignment, disagreement resolved by priority, result without its matching explanation, fabricated occurrence or financial mutation without a family contract invalidates the recommendation. Changed source/history coverage requires reevaluation.
