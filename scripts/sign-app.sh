#!/usr/bin/env bash
# Usage: sign-app.sh <Murmur.app> <identity or -> <entitlements>
# Signs nested code inside out with its own entitlements; --deep would stamp the app's onto Sparkle's helpers.
set -euo pipefail

APP="$1"
IDENTITY="$2"
ENTITLEMENTS="$3"

TIMESTAMP=--timestamp
[[ "$IDENTITY" == "-" ]] && TIMESTAMP=--timestamp=none

find "$APP/Contents" ! -type l \( -name '*.dylib' -o -name '*.framework' -o -name '*.xpc' -o -name '*.app' -o -name '*.appex' -o -name Autoupdate \) \
    | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- \
    | while IFS= read -r item; do
        codesign --force "$TIMESTAMP" --options runtime --preserve-metadata=entitlements --sign "$IDENTITY" "$item"
    done

codesign --force "$TIMESTAMP" --options runtime --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
