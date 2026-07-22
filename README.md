# Hubble Gateway SDK - iOS Quickstart

This is a **sample app** demonstrating how to integrate the
[HubbleGatewaySDK for iOS](https://github.com/HubbleNetwork/gateway-sdk-ios-releases)
— it is not itself a production app, just a reference. Demonstrates
the end-to-end integration path — permission flow, background-task
registration, SDK lifecycle, live BLE device feed, upload diagnostics —
and ships a copy-pasteable `GatewayController` you can lift straight
into your own app.

Looking for the Android equivalent? See
[quickstart-android](https://github.com/HubbleNetwork/quickstart-android).

For general Hubble Network documentation (not iOS/Android-SDK-specific),
see [docs.hubble.com](https://docs.hubble.com).

### The Hubble service UUID

`0xFCA6` is the short form of Hubble Network's Bluetooth-SIG-assigned
16-bit service UUID. In full 128-bit form it's:

```
0000FCA6-0000-1000-8000-00805F9B34FB
```

It's listed in the official [Bluetooth SIG 16-bit UUID assigned numbers
register](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf)
(page 119).

The SDK also scans for Tile's service UUID (`0xFEED`) by default, for
interoperability with the Tile network.

## Requirements

| Requirement | Version |
|-------------|---------|
| iOS deployment target | 17.0+ (uses `@Observable`) |
| Xcode | 15+ |
| macOS | 14+ (Xcode 15 host requirement) |

The `HubbleGatewaySDK` package itself targets iOS 16+; the sample app
bumps to 17 to use `@Observable` for view models. Nothing in the SDK
requires that bump — your own host app can stay on iOS 16.

## Setup

### Getting an SDK key

SDK keys (`hsk_...`) are currently issued manually. To obtain one:

1. You must have a Hubble account — sign up at
   [docs.hubble.com](https://docs.hubble.com) if you don't have one yet.
2. Contact us via [support@hubble.com](mailto:support@hubble.com) to
   discuss your intended gateway deployment use case. We'll generate a
   key for your organization.

### Configuring the key

The sample injects the Hubble SDK key via an xcconfig file that is
**not committed**. Before your first build:

```bash
cp Secrets.template.xcconfig Secrets.xcconfig
# edit Secrets.xcconfig and replace hsk_REPLACE_ME with your real key
```

`Secrets.xcconfig` is gitignored. The build injects
`HUBBLE_SDK_KEY` into `Info.plist` under the `HubbleSDKKey` key, and
`DefaultConfig.sdkKey` reads it back at launch. Missing / placeholder
values raise a `fatalError` on first launch so the misconfiguration is
loud.

> **Security note — don't copy this pattern into a production app.**
> The xcconfig keeps the key out of *git*, but it still ends up in the
> shipped binary (`Info.plist`), where it is trivially extractable from
> any App Store build. That's acceptable for a sample; for production,
> treat anything bundled with the app as public. Prefer fetching the
> key from your own backend after your own user authentication and
> passing it to `start(config:)` at runtime — the SDK itself never
> persists the key and only uses it once, at gateway registration
> (all subsequent traffic runs on short-lived tokens the SDK stores in
> the Keychain). If you cache the fetched key for background
> relaunches (`registerBackgroundTasks(configProvider:)`), put it in
> your app's Keychain, not in a file or `UserDefaults`.

## Run

```bash
open HubbleGatewaySample.xcodeproj
```

Then in Xcode:

1. Pick an iOS Simulator or your device as the run destination. BLE
   scanning **does not work on the Simulator** — deploy to a real
   device to see any beacon sightings.
2. **Run** (⌘R).
3. Tap **Start** on the Gateway section. The app will:
   1. Request Bluetooth authorization (system prompt).
   2. Request Location `WhenInUse` (system prompt).
   3. Present an in-app alert explaining why the SDK needs `Always`;
      tapping **Continue** fires the system "Change to Always Allow"
      prompt in-app. (iOS shows that upgrade prompt only once per
      install — after it's consumed, the alert offers **Open Settings**
      instead.)
   4. Request Motion & Fitness (system prompt; optional — denying it
      just degrades motion detection to a location-speed heuristic).
   5. Start the SDK and call `startScanning()` — the returned
      `ScanStartResult` reports anything still missing, which the app
      surfaces as a blocker alert. The SDK itself never presents a
      permission prompt.
   6. Wait for the BLE adapter to power on (a radio-off hint, distinct
      from permissions).

The `HubbleGatewaySDK` SwiftPM package is resolved from the public
[gateway-sdk-ios-releases](https://github.com/HubbleNetwork/gateway-sdk-ios-releases)
repository (`from: "0.6.0"`), so the project builds standalone —
just clone, add your SDK key, and run.

## What it demonstrates

| Feature | Where |
|---------|-------|
| Runtime Info.plist preflight (`validateIntegration()`) | `App/HubbleGatewaySampleApp.swift` — debug-only assertion |
| Register `BGTaskScheduler` handlers before launch completes | `App/HubbleGatewaySampleApp.swift` |
| Async permission escalation (`GatewayPermissions.request(...)`) with a custom in-app explainer — the SDK never prompts on its own | `Controller/AppModel.swift` — `runStart()` + `presentAlwaysExplainerAndAwait()` |
| Consuming `ScanStartResult` (missing-permission feedback from `startScanning()`) | `Controller/AppModel.swift` — `blockerMessage(for:)` |
| SDK state mirror as an `@Observable` wrapper | `Controller/GatewayController.swift` |
| Live BLE device list from `ScanListener` callbacks + dedup by peripheral | `Controller/GatewayController.swift` + `Views/BleDevicesSection.swift` |
| Reactive `AsyncStream<GatewayScanResult>` feed for multi-consumer subscribers | `GatewayController.discoveries()` |
| Active-mode toggle (pins motion to `.moving`) | `Views/GatewaySection.swift` |
| Upload diagnostics (pending / uploading / failed / last upload / bytes 24 h) | `Views/DiagnosticsSection.swift` |
| Last-known location + accuracy | `Views/LocationSection.swift` |
| Copy gateway ID to clipboard | `Views/GatewaySection.swift` |
| Full erasure (`deleteAllData()`) | `Views/RootView.swift` — bottom red button |
| Clear the in-memory devices list without touching the SDK buffer | `Views/BleDevicesSection.swift` — "Clear list" button |

## Layout

```
HubbleGatewaySample/
├── App/
│   ├── HubbleGatewaySampleApp.swift   @main, registerBackgroundTasks + validateIntegration
│   └── DefaultConfig.swift            Reads HubbleSDKKey from Info.plist
│
├── Controller/                        <-- COPY THIS FOLDER INTO YOUR APP
│   ├── GatewayController.swift        @Observable SDK wrapper (state + ScanListener bridge)
│   ├── DiscoveredDevice.swift         Row model for the live device list
│   └── AppModel.swift                 Sample UI-flow glue (alerts, start orchestration)
│
└── Views/
    ├── RootView.swift                 List with all sections + alerts
    ├── PermissionsSection.swift       BT / Location / Motion status
    ├── GatewaySection.swift           State / Scanning / gatewayId / Start / Active mode
    ├── DiagnosticsSection.swift       Upload counters
    ├── LocationSection.swift          Last fix + accuracy
    ├── BleDevicesSection.swift        Live devices + "Clear list"
    └── StatusRow.swift                Reusable label / value / tone row
```

## Reusing `GatewayController` in your own app

`Controller/GatewayController.swift` is designed to be copy-pasted
verbatim. It has zero sample-app-specific dependencies — no SwiftUI,
no view state, no alert bindings. What it gives you:

- `@Observable` mirrors of every SDK state field (initialization,
  scanning, gatewayId, last location, upload diagnostics, permissions,
  BT adapter powered state).
- A 5 s polling task + `didBecomeActive` observer so state refreshes
  when the user returns from Settings.
- A `ScanListener` bridge that fans sightings out to (a) an observable
  `[DiscoveredDevice]` list and (b) any number of independent
  `AsyncStream<GatewayScanResult>` subscribers.
- Wait helpers (`waitForBluetoothPoweredOn`) that let start-flow
  callers surface a "radio is off" hint after scanning starts (the
  SDK's central is only created once Bluetooth permission is
  determined, so call it after the permission flow).

`AppModel.swift` is intentionally **not** meant to be copied — it's
the sample's UI-flow orchestration (alert bindings, error surfacing,
the SwiftUI-alert-as-continuation trick for the Always explainer).
Your app will have its own equivalent.

## Privacy & data collection

The sample doesn't surface the data-collection opt-out toggle in the
UI — you're expected to add that to your own settings screen. The
underlying SDK calls are:

```swift
HubbleGateway.shared.setDataCollectionEnabled(false)  // opt out (persisted)
HubbleGateway.shared.deleteAllData()                  // GDPR erasure
```

The bottom red **Delete all data** button in `RootView` calls
`deleteAllData()` (without flipping the toggle) so you can watch the
DB clear itself in the diagnostics counters.

## License

[Apache License 2.0](LICENSE) — Copyright 2026 Hubble Network, Inc.

The license covers this sample app's source code. The Hubble Gateway
SDK itself and its service are licensed separately — using them in
production requires an SDK key issued by Hubble Network.
