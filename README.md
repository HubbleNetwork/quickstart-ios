# HubbleGatewaySample

Reference iOS app that consumes [`gateway-sdk`](../gateway-sdk) — the iOS port
of the Android Hubble Gateway SDK.

## What it shows

- **Permission flow** — current Bluetooth and Location authorization, with a
  call to Settings if the user needs to upgrade to `Always`.
- **SDK lifecycle** — Start / Stop scanning, on-demand registration, delete
  all data.
- **Gateway identity** — displays the server-issued `gatewayId` once
  registration succeeds.
- **Upload diagnostics** — pending / uploading / failed counts, last batch,
  bytes uploaded in the past 24 hours.

## Run

```bash
open HubbleGatewaySample.xcodeproj
```

Then in Xcode:

1. Pick an iOS Simulator (or your device) as the run destination.
2. **Run** (⌘R). On first launch the SDK key and API URL fields will be empty
   — paste a real key and tap **Start**. Both values are persisted in
   `UserDefaults` so subsequent runs come up wired.

The local `HubbleGatewaySDK` SwiftPM package is referenced at `../gateway-sdk`,
so any change you make to the SDK is picked up by the next sample build.

## Layout

```
HubbleGatewaySample/
├── HubbleGatewaySampleApp.swift   @main, calls registerBackgroundTasks()
├── AppModel.swift                 @Observable bridge over the @MainActor SDK
├── RootView.swift                 List with all sections
├── PermissionsSection.swift       Auth status + Open Settings button
├── ConfigSection.swift            SDK key + API URL fields
├── GatewaySection.swift           State / Scanning / Gateway ID / Start
├── DiagnosticsSection.swift       Upload counters
├── StatusRow.swift                Small reusable row
├── Info.plist                     Background modes + usage strings
└── Assets.xcassets                AccentColor + AppIcon
```

## iOS 17+ note

The sample targets iOS 17 to use `@Observable`. The SDK still targets iOS 16
and works in older host apps.
