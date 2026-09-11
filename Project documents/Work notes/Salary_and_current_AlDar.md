# Salary and current AlDar

<a id="packet-al-dar-planner-reference-packet"></a>

**Owners:** [FW-P3-08](../FUTURE_WORK.MD#fw-p3-08), [FW-P3-19](../FUTURE_WORK.MD#fw-p3-19).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

How should current Salary/This Month estimate INR remittance using Al Dar and a manual current-rate override?

## Current conclusion

UD-09 narrows QAR→INR to the current monthly salary/budget estimate; UD-10 also removes historical conversions from current net worth. The broad old Al Dar/historical/2021 direction is superseded. Existing Qatar Airways salary actuals, history, manual current-rate planner, coherent Save and fee validation are accepted; a live Al Dar source is not yet integrated or accepted.

The proposed bounded slice uses one forward amount-specific current quote, clearly indicative, with an explicit manual override. Existing ADR-045 must be aligned or superseded before implementation changes its accepted manual authority. The forward QAR funding calculation needs exact amount binding, one recalculation contract and approved rounding upward to the QAR minor unit where required; do not invert an indicative band into an invented executable quote. Configured QAR fee is a separate non-negative manual amount; effective fee remains zero when no India funding is required. No fixed haircut, spread, retired 0.75 factor or automatic fee fetching is approved.

Historical public inspection found the Al Dar portal's JavaScript POST `Home/GetRate`, INR with QAR amount and `isFCY=false`. Two sampled amounts in the observed band returned proportionate results, but earlier amount sensitivity and unsafe reverse use were not disproved. The reply supplied no authoritative quote timestamp, expiry, fee or executable quote ID. No observed authentication barrier is not provider permission or suitability. It remains an indicative reference, not proof of the actual future transfer proceeds.

A draft provider inquiry in the previous packet asked whether personal automated access/cache is permitted and what amount, rate/fee, source-time, expiry and indicative/executable semantics apply. It was a proposed inquiry, not sent or answered. This documentation task sends no inquiry and makes no new provider observation.

Salary-to-bank reconciliation is a separate retained item requiring genuine payroll/bank evidence and an approved exact match. Salary components must never manufacture a bank transaction. Broader Salary workflow remains on its existing card beyond the required Sprint 94 current slice.

## Evidence and references

Owner UD-09/10, 2026-09-10; source observation in the 2026-09-10 Al Dar packet; [official portal](https://www.aldarexchange.com/aldarportal/Home). These are historical discovery facts, not a new live qualification.

## Unresolved decision or blocker

Approve current use/suitability, request amount identity, source/fetch/freshness/cache and failure/override behavior, one recalculation/rounding rule, fee separation and ADR-045 alignment. Provider permission remains unresolved.

## What would invalidate this conclusion

Changed endpoint/terms, missing amount binding, stale or timestamp-less results represented as current executable rates, reverse-rate assumptions, inferred fees or any automatic replacement of manual authority invalidates the proposal.
