#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your Apple Developer team ID}"
command -v xcodegen >/dev/null
xcodegen generate --spec project.yml
xcodebuild -project DataXInvesting.xcodeproj -scheme DataXInvesting \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/DataXInvesting.xcarchive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" -allowProvisioningUpdates archive
echo 'Archive created. Open it in Xcode Organizer to validate and distribute through TestFlight/App Store.'
