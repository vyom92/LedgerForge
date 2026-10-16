#!/bin/bash
set -euo pipefail

# A pinned local build dependency; credentials and tunnel profiles are never bundled.
source_client="${LEDGERFORGE_TUNNEL_CLIENT:?Pinned tunnel-client path is required}"
identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [[ -z "$identity" || "$identity" == "-" ]]; then
    echo 'Financial MCP helpers require the app stable signing identity.' >&2
    exit 1
fi
helpers="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"
resources="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
entitlements="$SRCROOT/FinancialMCP/child.entitlements"
staging="$TARGET_TEMP_DIR/FinancialMCPHelpers"
/bin/mkdir -p "$helpers" "$resources" "$staging"
objects=()
for architecture in $ARCHS; do
    object="$TARGET_TEMP_DIR/FinancialMCPGuardian-$architecture"
    "$DT_TOOLCHAIN_DIR/usr/bin/clang" -arch "$architecture" -isysroot "$SDKROOT" \
        -mmacosx-version-min="$MACOSX_DEPLOYMENT_TARGET" -O2 -Wall -Wextra \
        "$SRCROOT/FinancialMCP/guardian.c" -o "$object"
    objects+=("$object")
done
"$DT_TOOLCHAIN_DIR/usr/bin/lipo" -create "${objects[@]}" -output "$staging/FinancialMCPGuardian"
/bin/cp "$source_client" "$staging/tunnel-client"
/bin/cp "$SRCROOT/FinancialMCP/financial_mcp_control.py" "$resources/financial_mcp_control.py"
# codesign creates temporary sibling files. The script sandbox permits that in
# TARGET_TEMP_DIR; the bundle outputs remain limited to the declared files.
for helper in "$staging/FinancialMCPGuardian" "$staging/tunnel-client"; do
    /bin/chmod u+w "$helper"
    /usr/bin/codesign --force --sign "$identity" --entitlements "$entitlements" --options runtime --timestamp=none "$helper"
    /usr/bin/codesign --verify --strict "$helper"
    /usr/bin/install -m 755 "$helper" "$helpers/$(/usr/bin/basename "$helper")"
done
