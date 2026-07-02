# Hubble Gateway SDK - iOS Quickstart

Reference iOS app that consumes [`gateway-sdk`](../gateway-sdk). Demonstrates
the end-to-end integration path — permission flow, background-task
registration, SDK lifecycle, live BLE device feed, upload diagnostics —
and ships a copy-pasteable `GatewayController` you can lift straight
into your own app.

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
   2. Wait for the BLE adapter to power on.
   3. Request Location `WhenInUse` (system prompt).
   4. Present an in-app alert explaining why the SDK needs `Always`;
      tapping **Open Settings** opens iOS Settings for this app so you
      can escalate.
   5. Begin scanning once permissions are usable.

The local `HubbleGatewaySDK` SwiftPM package is referenced at
`../gateway-sdk`, so any SDK edit is picked up by the next sample
build without republishing.

## What it demonstrates

| Feature | Where |
|---------|-------|
| Runtime Info.plist preflight (`validateIntegration()`) | `App/HubbleGatewaySampleApp.swift` — debug-only assertion |
| Register `BGTaskScheduler` handlers before launch completes | `App/HubbleGatewaySampleApp.swift` |
| Async permission escalation (`GatewayPermissions.request(...)`) with a custom in-app explainer | `Controller/AppModel.swift` — `runStart()` + `presentAlwaysExplainerAndAwait()` |
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
  callers block on adapter readiness before firing permission prompts.

`AppModel.swift` is intentionally **not** meant to be copied — it's
the sample's UI-flow orchestration (alert bindings, error surfacing,
the SwiftUI-alert-as-continuation trick for the Always explainer).
Your app will have its own equivalent.

## Privacy & data collection

The sample doesn't surface the data-collection opt-out toggle in the
UI — you're expected to add that to your own settings screen. The
underlying SDK calls are:

```swift
HubbleGatewaySDK.shared.setDataCollectionEnabled(false)  // opt out (persisted)
HubbleGatewaySDK.shared.deleteAllData()                  // GDPR erasure
```

The bottom red **Delete all data** button in `RootView` calls
`deleteAllData()` (without flipping the toggle) so you can watch the
DB clear itself in the diagnostics counters.

## License

Proprietary — Hubble Network, Inc.
