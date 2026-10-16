# Financial MCP

Financial MCP exposes four read-only operations from the running Mac app:
`get_financial_status`, `get_portfolio_overview`, `get_reserve_status` and
`get_planning_context`. Settings > Financial MCP controls the connection and the
information permitted for each operation. Saving sharing choices stops the
service. Start it after reviewing those choices. Revoke stops sharing, removes
the saved runtime key and clears all four permissions.

The app owns its loopback listeners, guardian and tunnel. Quitting the app closes
them. The guardian also detects unexpected app exit. Sleep tears down transport;
wake starts a new transport generation while preserving the owner's start/stop
intent. Connected requires a recent successful OpenAI control-plane poll. A
connected tunnel does not by itself prove that a financial tool has been called;
Settings shows the last financial request separately.

The Desktop launcher controls the running app. It supports Status, Start, Stop,
Restart, Settings, Enable, Disable and Revoke. It does not start a second server
or launch a stopped app. Keep a saved launcher with the app location from which
it was created; save it again after moving the app.

## Presentation contract

Reads run synchronously on the UI actor against the existing Dashboard,
investment and Budget Planning presentation. They do not open a database,
import statements, fetch prices, save plans or migrate storage. Exact amounts
are decimal strings or numerator/denominator pairs; displayed strings use the
same native formatting. Observation dates and cached/partial qualifications
remain attached. Zurich allocated contributions are distinct from fund cost;
conditional reserve figures never become an aggregate funded total.

Every successful response includes `snapshot_id`, `provider_generation` and
`presentation_revision`. To combine the four responses, read the first tool and
pass its `snapshot_id` as `expected_snapshot` to the remaining tools. A provider
replacement, presentation change or incomplete update fails explicitly instead
of returning a mixed snapshot. Call again after the UI settles.

`get_planning_context` without `month` describes the actual selected editor,
saved plan, retained entries, validation and unsaved scenario. An explicit
`month` in `YYYY-MM` reads hydrated saved/retained records without selecting that
month or calculating a new projection. Missing records remain null. Retained
incomplete input remains text and is not represented as an accepted amount.

## Build and qualification

The Xcode build phase uses `script/embed_financial_mcp.sh`. The
`LEDGERFORGE_TUNNEL_CLIENT` build setting selects the pinned local Homebrew
`tunnel-client` 0.0.11 binary. The script compiles the guardian for the requested
architectures, embeds both helpers and signs them with the app's stable signing
identity and sandbox inheritance. The currently qualified dependency is the
Apple Silicon Mac binary. No credential or tunnel profile is bundled.

The runtime key is stored in the app-specific Keychain scope. Control discovery
is restricted to the current user. Financial payloads and keys are omitted from
runtime diagnostics. Debug-only isolated qualification can use
`LEDGERFORGE_MCP_LOCAL_ONLY`, `LEDGERFORGE_MCP_RUNTIME_KEY` and
`LEDGERFORGE_MCP_QUALIFICATION`; these overrides are not available in Release.
The normal test host never activates Financial MCP.

Run the seven nonfinancial access/protocol definitions through the canonical
validation driver:

```sh
./script/validate.sh test-focused LedgerForgeTests/FinancialMCPProtocolTests
```

Authentic qualification requires the owner's field-sharing approval and an
isolated namespace populated from a verified native backup. Compare the actual
UI and tool responses in memory. Keep financial values, source material and
credentials out of Git and ordinary evidence files. Operational receipts and
acceptance limitations belong in the campaign's external evidence directory.
