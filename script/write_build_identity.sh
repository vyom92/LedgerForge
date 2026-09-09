#!/bin/bash
set -eu
# Xcode invokes this phase for direct Run as well as repository validation builds.
# It writes only into the product; runtime never reads the live checkout.
revision=unavailable
worktree=unknown
if observed=$(/usr/bin/env -u SDKROOT -u XCODE_DEVELOPER_DIR_PATH /usr/bin/git --no-optional-locks -C "$SRCROOT" rev-parse --verify HEAD 2>/dev/null); then
    revision="$observed"
    if state=$(/usr/bin/env -u SDKROOT -u XCODE_DEVELOPER_DIR_PATH /usr/bin/git --no-optional-locks -C "$SRCROOT" status --porcelain --untracked-files=normal 2>/dev/null); then
        worktree=clean
        [[ -z "$state" ]] || worktree=dirty
    fi
fi
output="$PROJECT_TEMP_DIR/LedgerForgeBuildIdentity-$CONFIGURATION.json"
/bin/mkdir -p "$(dirname "$output")"
/usr/bin/jq -n --arg revision "$revision" --arg worktree "$worktree" \
    --arg builtAt "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" --arg configuration "$CONFIGURATION" \
    '{revision:$revision,worktree:$worktree,builtAt:$builtAt,configuration:$configuration}' > "$output"
