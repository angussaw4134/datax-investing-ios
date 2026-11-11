# DataX Investing for iPhone

Native SwiftUI monitoring app for the DataX wallet and existing trading-agent feed. Uses the deployed HTTPS monitoring service. Includes email-code sign-in, owner-approved viewer access, SOL balance charts with touch selection, token holdings, agent-reported strategy activity, account deletion and optional device authentication.

This app cannot sign transactions, move funds, collect fees or place trades. Balance changes are not trading profit; strategy profit is explicitly agent-reported.

## GitHub build

Push this repository to GitHub. The **Build DataX iOS** Actions workflow runs on a macOS runner, builds and tests an iPhone simulator target, then creates an unsigned device archive and IPA. Download artifacts from the completed workflow run.

- `DataX-simulator`: simulator application; cannot install on an iPhone.
- `DataX-unsigned-device`: unsigned archive and IPA; requires valid Apple signing/provisioning before device installation.
- `DataX-test-results`: XCTest result bundle.

These artifacts are not App Store or TestFlight releases. An unsigned IPA is not directly installable. Apple signing credentials are not included. Build success must be established by an actual completed Actions run.

## Local Xcode build

Requires macOS, Xcode with iOS 17 or later SDK and XcodeGen.

```sh
brew install xcodegen
xcodegen generate --spec ios/project.yml
open ios/DataXInvesting.xcodeproj
```

For a signed archive, choose your Apple Developer team and an available bundle identifier, or run `APPLE_TEAM_ID=YOUR_TEAM_ID bash ios/archive.sh`. Validate and distribute from Xcode Organizer using your eligible Apple distribution method.

The app connects to `https://datax-monitor.accesshubv1.workers.dev`. Email delivery, account approval and data availability depend on the deployed service. No server secrets belong in this repository or application. Test sign-in, access revocation, stale/offline behavior, accessibility and account deletion on a device before release.