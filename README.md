# PulseCache

[![Unit tests](https://github.com/tinphamswe/PulseCache/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/tinphamswe/PulseCache/actions/workflows/unit-tests.yml)
[![UI tests](https://github.com/tinphamswe/PulseCache/actions/workflows/ui-tests.yml/badge.svg)](https://github.com/tinphamswe/PulseCache/actions/workflows/ui-tests.yml)

An offline-first REST API monitoring app for developers, built with SwiftUI and Swift concurrency. The planned MVP lets you save requests, inspect responses, view cached results offline, and compare request history.

Milestone 1 provides the domain models, request validation and building, header redaction, injectable dependencies, in-memory repositories, and test infrastructure. The app currently displays the starter screen. Networking execution, the three-screen UI, Core Data persistence, and Keychain integration are planned in subsequent milestones.

## Development

- The app supports iOS 15 and later. Test bundles require iOS 17 or later.
- Use Xcode 26.3 or later. Open `PulseCache.xcodeproj` and select the shared `PulseCache` scheme.
- Ruby 3.3 and Bundler are used for Fastlane. Install dependencies with `bundle install`.
- Run tests in Xcode with **Product → Test**, or use the same lanes as CI:

```sh
bundle exec fastlane ios unit_tests
bundle exec fastlane ios ui_tests
```

The default simulator is **iPhone 16 Pro / iOS 18.6**. To use another installed simulator locally:

```sh
SCAN_DEVICE="iPhone 13 (18.6)" bundle exec fastlane ios unit_tests
SCAN_DEVICE="iPhone 13 (18.6)" bundle exec fastlane ios ui_tests
```

Set `DEVELOPER_DIR` if your command-line tools point to a different Xcode installation. Add `clean:true` to either lane when a clean build is needed.

## Continuous integration

GitHub Actions runs the unit/integration and UI lanes separately on pushes and pull requests to `main`, with manual runs available. Both use macOS 15, Xcode 26.3, and the committed Gemfile.lock. Reports and `.xcresult` bundles, including coverage, are uploaded as artifacts for 14 days. Simulator tests require no signing credentials or repository secrets.

Unit and integration tests use Swift Testing; UI tests use XCTest. Test doubles live in `PulseCacheTests/TestDoubles/`. Unit tests inject collaborators; integration suites explicitly verify their real composition. Tests use simulated network responses and in-memory storage.

The Fastlane lane structure and reusable setup action follow [CBBootcamp](https://github.com/tinphamswe/CBBootcamp).
