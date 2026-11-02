# Live Timer Connect

Timers and alarms that stay together on iPhone and iPad.

Live Timer Connect is a SwiftUI app for iOS 17+ with:

- Quick timers for 1, 2, 3, 5, 10, and 30 minutes.
- Custom quick timers with a four-wheel days/hours/minutes/seconds picker, up to **29d 23h 59m 59s**.
- Multiple timers running at once.
- iCloud key-value sync between devices signed in to the same Apple ID.
- A configurable small Home Screen and Lock Screen widget: choose a saved quick timer, tap to start, then pause or stop it while it runs.
- Live Activities on the Lock Screen and in the Dynamic Island with pause, stop, restart, and dismiss controls. A finished timer stays visible with **Restart** and **X** until you dismiss it.
- Alarms for any hour and minute from 12 AM to 12 AM, without Live Activities. Alarm notifications offer **Stop** and **Snooze 9 minutes**.
- A loud custom 27-second `ding.wav` made of repeated dings for timer and alarm notifications.
- Critical alerts with `UNNotificationSound.criticalSoundNamed(_:withAudioVolume: 1.0)` when the entitlement and authorization are available.

## Download

The unsigned IPA is built automatically by GitHub Actions and published at:

**https://kingyorkson.github.io/livetimerconnect/**

The same build is attached to the latest GitHub release. Use AltStore, SideStore, Sideloadly, or another signing tool to install it on a device.

## Critical alerts and Do Not Disturb

Timer and alarm notifications request `.criticalAlert` and use a critical sound at volume `1.0`. When iOS grants critical alerts, they bypass Do Not Disturb, silent mode, and the physical mute switch, similar to a native alarm.

Critical alerts require Apple's restricted `com.apple.developer.usernotifications.critical-alerts` entitlement. The app's entitlements file includes it, but an unsigned IPA cannot carry entitlements, and a personal Apple ID signature will normally strip it unless your sideloading tool supports custom entitlement injection.

- If your signing tool supports custom entitlements, inject `com.apple.developer.usernotifications.critical-alerts` with the value `<true/>` during signing.
- If it does not, the app automatically falls back to standard time-sensitive notifications with the same loud custom sound. Add **Live Timer Connect** to **Settings → Focus → Do Not Disturb → Allowed Apps** so those notifications can still appear.
- Critical alerts are reserved for medical, home-security, and public-safety apps. Apple may reject or remove the entitlement for other apps.

The custom sound repeats dings for 27 seconds, which is just under iOS's 30-second notification sound limit. Timers schedule one follow-up ring 30 seconds later; alarms schedule two follow-up rings at 30-second intervals. Stopping, snoozing, dismissing, or restarting cancels the remaining rings. For a repeating alarm, the daily alarm request stays scheduled for tomorrow.

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
- Critical alerts (restricted entitlement; automatic fallback when unavailable)
- Live Activities
- A configurable Home Screen / Lock Screen widget

An unsigned IPA cannot carry these entitlements. When the app is signed with an Apple ID that does not support them, it falls back to local storage and local notifications. iCloud sync and cross-process Live Activity updates require a signed build with matching entitlements.

## Project layout

```
LiveTimerConnect/          App target: SwiftUI views, app model, sync, notifications, Live Activities
LiveTimerConnectWidget/    Widget extension: Live Activity UI and the configurable quick timer widget
Shared/                    Models, shared App Group store, intents, and action handling
LiveTimerConnect/Resources Asset catalog, app icon, and ding.wav
docs/                      GitHub Pages landing page and AltStore source template
project.yml                XcodeGen project definition
.github/workflows/         CI build, release, and Pages deployment
```

## Notes

- The app targets iOS 17 and later on iPhone and iPad.
- iCloud sync uses `NSUbiquitousKeyValueStore`; no data is sent to a server owned by this project.
- The quick timer widget supports the small Home Screen size and the rectangular Lock Screen accessory. Add it from the widget gallery, then long-press and edit it to choose a saved quick timer.
- The widget starts timers without opening the app. It still needs the App Group to read the timer list in the widget extension; an unsigned sideload may not provide that.
- Alarm snooze is fixed at 9 minutes, matching the request. It is not customizable like the Apple Clock app.
- The GitHub Actions build is intentionally unsigned because no signing certificate is stored in the repository.
- Rotate any personal access token used to set up the repository after the first push.
