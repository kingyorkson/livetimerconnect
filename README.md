# Live Timer Connect

Timers and alarms that stay together on iPhone and iPad.

Live Timer Connect is a SwiftUI app for iOS 17+ with:

- Quick timers for 1, 2, 3, 5, 10, and 30 minutes.
- Custom quick timers with a four-wheel days/hours/minutes/seconds picker, up to **29d 23h 59m 59s**.
- Multiple timers running at once.
- iCloud key-value sync between devices signed in to the same Apple ID.
- Live Activities on the Lock Screen and in the Dynamic Island with pause, stop, restart, and dismiss controls.
- Alarms for any hour and minute from 12 AM to 12 AM, without Live Activities.
- A custom 3.2-second `ding.wav` for timer and alarm notifications.

## Download

The unsigned IPA is built automatically by GitHub Actions and published at:

**https://kingyorkson.github.io/livetimerconnect/**

The same build is attached to the latest GitHub release. Use AltStore, SideStore, Sideloadly, or another signing tool to install it on a device.

## Build locally

Requirements:

- macOS with Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
brew install xcodegen
xcodegen generate
open LiveTimerConnect.xcodeproj
```

Build the `LiveTimerConnect` scheme for a connected iPhone or iPad. Signing must be configured in Xcode with a development team that owns the bundle identifiers below.

## CI build

Every push to `main` runs `.github/workflows/build.yml`, which:

1. Generates the Xcode project with XcodeGen.
2. Archives the app for `generic/platform=iOS` without code signing.
3. Packages `Payload/LiveTimerConnect.app` as `LiveTimerConnect.ipa`.
4. Uploads the IPA as a workflow artifact and GitHub release asset.
5. Publishes the IPA, landing page, and AltStore source to GitHub Pages.

The workflow can also be started manually with `workflow_dispatch`.

## Bundle identifiers and capabilities

| Target | Bundle identifier |
| --- | --- |
| App | `com.kingyorkson.LiveTimerConnect` |
| Widget / Live Activity extension | `com.kingyorkson.LiveTimerConnect.Widget` |

The app uses:

- App Group `group.com.kingyorkson.LiveTimerConnect`
- iCloud key-value storage
- Time-sensitive notifications
- Live Activities

An unsigned IPA cannot carry these entitlements. When the app is signed with an Apple ID that does not support them, it falls back to local storage and local notifications. iCloud sync and cross-process Live Activity updates require a signed build with matching entitlements.

## Project layout

```
LiveTimerConnect/          App target: SwiftUI views, app model, sync, notifications, Live Activities
LiveTimerConnectWidget/    Widget extension: Lock Screen and Dynamic Island Live Activity UI
Shared/                    Models, shared App Group store, intents, and action handling
LiveTimerConnect/Resources Asset catalog, app icon, and ding.wav
docs/                      GitHub Pages landing page and AltStore source template
project.yml                XcodeGen project definition
.github/workflows/         CI build, release, and Pages deployment
```

## Notes

- The app targets iOS 17 and later on iPhone and iPad.
- iCloud sync uses `NSUbiquitousKeyValueStore`; no data is sent to a server owned by this project.
- The GitHub Actions build is intentionally unsigned because no signing certificate is stored in the repository.
- Rotate any personal access token used to set up the repository after the first push.
