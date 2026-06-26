import Foundation
import Observation
import HubbleGatewaySDK
import UIKit
import CoreLocation

/// Glue between the SDK's `@MainActor` façade and SwiftUI views.
///
/// Orchestrates a single Start flow: requests BT + location authorization,
/// boots the SDK, then prompts the user to escalate location to `Always`
/// via Settings. Also collects raw scan results into a per-peripheral
/// `discoveredDevices` map (Android-style live device list).
@MainActor
@Observable
final class AppModel: NSObject {

    // Permission state
    var permissions: PermissionStatus = GatewayPermissions.currentStatus()

    // SDK state mirrored for the UI
    var initializationState: InitializationState = .notStarted
    var isScanning: Bool = false
    var isActiveScanning: Bool = false
    var gatewayId: String?
    var lastLocation: LocationFix?
    var lastDiagnostics: UploadDiagnostics?
    var lastError: String?

    // Single Start flow state
    var showAlwaysExplainerAlert: Bool = false
    /// Non-nil when the user tapped Start but a precondition (BT off,
    /// permission denied, …) blocks it. RootView shows an alert with
    /// this message.
    var startBlocker: String?

    // Live BLE device feed
    var discoveredDevices: [DiscoveredDevice] = []
    private var deviceIndex: [UUID: DiscoveredDevice] = [:]

    var apiBaseURLString: String {
        didSet { UserDefaults.standard.set(apiBaseURLString, forKey: "demo.apiBase") }
    }

    private var pollTask: Task<Void, Never>?
    private var awaitingAlwaysPrompt = false
    private var lastSeenLocationStatus: LocationAuthorization = .notDetermined
    private var scanCollector: ScanCollector?

    /// Set when the user taps "Open Settings" on the start blocker alert.
    /// Becoming active again retries `start()` once so the user doesn't
    /// have to tap Start a second time after fixing the blocker.
    private var pendingStartRetry = false

    /// Dedicated CL manager whose only job is delivering authorization
    /// callbacks via `locationManagerDidChangeAuthorization(_:)`. Kept
    /// alive for the AppModel's lifetime — see GatewayPermissions for
    /// the rate-limit reason we don't make these on the fly.
    private let locationAuthManager = CLLocationManager()

    override init() {
        let legacyDefaults: Set<String> = ["https://api.hubblenetwork.com"]
        if let stored = UserDefaults.standard.string(forKey: "demo.apiBase"),
           legacyDefaults.contains(stored) {
            UserDefaults.standard.removeObject(forKey: "demo.apiBase")
        }
        self.apiBaseURLString = UserDefaults.standard.string(forKey: "demo.apiBase")
            ?? DefaultConfig.apiBaseURLString
        super.init()
        lastSeenLocationStatus = permissions.location
        locationAuthManager.delegate = self
        refresh()
        startPolling()
    }

    // MARK: - Single Start flow

    /// One-tap Start: ensures the SDK is configured + running, kicks off
    /// permission requests in order (BT adapter init via CBCentralManager
    /// → location WhenInUse via SDK), and queues the "Always" explainer
    /// dialog once WhenInUse is granted.
    func start() {
        refresh()

        if let blocker = checkStartPreconditions() {
            startBlocker = blocker
            return
        }

        guard let url = URL(string: apiBaseURLString) else {
            lastError = "API URL is invalid"
            return
        }

        if HubbleGatewaySDK.shared.initializationState != .ready {
            do {
                let config = HubbleGatewayConfig(
                    sdkKey: DefaultConfig.sdkKey,
                    apiBaseURL: url
                )
                try HubbleGatewaySDK.shared.start(config: config)
                let collector = ScanCollector { [weak self] result in
                    Task { @MainActor in self?.ingestDiscovery(result) }
                } onDiagnostics: { [weak self] diagnostics in
                    Task { @MainActor in self?.lastDiagnostics = diagnostics }
                }
                HubbleGatewaySDK.shared.addScanListener(collector)
                scanCollector = collector
                lastError = nil
            } catch {
                lastError = String(describing: error)
                refresh()
                return
            }
        }

        // BT adapter state is only readable after the SDK's BleScanner
        // has spun up its CBCentralManager and received the first delegate
        // callback. Poll up to ~8 s — the user may still be looking at the
        // first-run Bluetooth permission prompt during that window.
        Task { @MainActor in
            for _ in 0..<80 {
                if HubbleGatewaySDK.shared.isBluetoothPoweredOn { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard HubbleGatewaySDK.shared.isBluetoothPoweredOn else {
                startBlocker = "Bluetooth is turned off. Turn it on in Control Center or Settings, then tap Start again."
                return
            }

            // If location auth isn't Always yet, queue the explainer alert.
            // The system prompt for WhenInUse fires inside startScanning().
            if permissions.location != .authorizedAlways {
                awaitingAlwaysPrompt = true
            }

            HubbleGatewaySDK.shared.startScanning()
            refresh()
        }
    }

    func stop() {
        HubbleGatewaySDK.shared.stopScanning()
        refresh()
    }

    /// Sync precondition check — only validates things we can read
    /// without spinning up CBCentralManager. The actual BT adapter
    /// on/off check happens AFTER the SDK is initialized in `start()`,
    /// because we'd otherwise need a duplicate CBCentralManager.
    /// `.notDetermined` permissions are NOT blockers — the SDK will
    /// trigger the appropriate iOS prompt during `startScanning`.
    private func checkStartPreconditions() -> String? {
        switch permissions.bluetooth {
        case .denied, .restricted:
            return "Bluetooth access is denied. Enable it in Settings → HubbleGatewaySample → Bluetooth, then tap Start again."
        case .unknown:
            return "Bluetooth state is unavailable. Check Settings."
        case .notDetermined, .authorized:
            break
        }
        switch permissions.location {
        case .denied, .restricted:
            return "Location access is denied. Grant it in Settings → HubbleGatewaySample → Location, then tap Start again."
        case .notDetermined, .authorizedWhenInUse, .authorizedAlways:
            break
        }
        return nil
    }

    func registerNow() {
        Task {
            do {
                try await HubbleGatewaySDK.shared.registerIfNeeded()
                lastError = nil
            } catch {
                lastError = String(describing: error)
            }
            refresh()
        }
    }

    func deleteAll() {
        HubbleGatewaySDK.shared.deleteAllData()
        discoveredDevices = []
        deviceIndex = [:]
        refresh()
    }

    func setActiveScanning(_ enabled: Bool) {
        if enabled {
            HubbleGatewaySDK.shared.startActiveScanning()
        } else {
            HubbleGatewaySDK.shared.stopActiveScanning()
        }
        refresh()
    }

    // MARK: - Always-explainer dialog

    /// Called when the user confirms the in-app explainer. Opens iOS
    /// Settings for this app so the user can flip Location → Always.
    func confirmAlwaysExplainer() {
        showAlwaysExplainerAlert = false
        openSettings()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// "Open Settings" handler on the start blocker alert. Arms a one-shot
    /// retry so when the user returns to the app, `start()` runs again
    /// automatically (no second tap on the Start button).
    func openSettingsForStartBlocker() {
        pendingStartRetry = true
        startBlocker = nil
        openSettings()
    }

    /// Called from the root view when the scene becomes active. Forces an
    /// immediate `refresh()` (no waiting on the 5 s poll) and consumes
    /// the pending Start retry if one is armed.
    func onSceneBecameActive() {
        refresh()
        if pendingStartRetry {
            pendingStartRetry = false
            start()
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.refresh()
            }
        }
    }

    func refresh() {
        let previousLocationStatus = lastSeenLocationStatus
        permissions = GatewayPermissions.currentStatus()
        lastSeenLocationStatus = permissions.location
        initializationState = HubbleGatewaySDK.shared.initializationState
        isScanning = HubbleGatewaySDK.shared.isScanning
        isActiveScanning = HubbleGatewaySDK.shared.isActiveScanningOverride
        gatewayId = HubbleGatewaySDK.shared.gatewayId
        lastLocation = HubbleGatewaySDK.shared.lastLocation

        // Detect a WhenInUse grant transition and queue the explainer dialog.
        if awaitingAlwaysPrompt,
           previousLocationStatus != .authorizedWhenInUse,
           permissions.location == .authorizedWhenInUse {
            showAlwaysExplainerAlert = true
            awaitingAlwaysPrompt = false
        } else if permissions.location == .authorizedAlways {
            awaitingAlwaysPrompt = false
        }

        Task {
            if let snap = try? await HubbleGatewaySDK.shared.uploadDiagnostics() {
                lastDiagnostics = snap
            }
        }
    }

    // MARK: - Scan ingest

    private func ingestDiscovery(_ result: GatewayScanResult) {
        let id = result.peripheralIdentifier
        if var existing = deviceIndex[id] {
            existing.lastRSSI = result.rssi
            existing.lastSeen = result.timestamp
            existing.sightingCount += 1
            existing.lastServiceUUID = result.serviceUUID.uuidString
            existing.lastServiceDataBytes = result.serviceData.count
            deviceIndex[id] = existing
        } else {
            deviceIndex[id] = DiscoveredDevice(
                peripheralId: id,
                lastServiceUUID: result.serviceUUID.uuidString,
                lastServiceDataBytes: result.serviceData.count,
                lastRSSI: result.rssi,
                firstSeen: result.timestamp,
                lastSeen: result.timestamp,
                sightingCount: 1
            )
        }
        discoveredDevices = deviceIndex.values.sorted { $0.lastSeen > $1.lastSeen }
    }
}

extension AppModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }
}

/// Bridge from `ScanListener` protocol to the @MainActor `AppModel`.
private final class ScanCollector: ScanListener {
    private let onResult: @Sendable (GatewayScanResult) -> Void
    private let onDiagnostics: @Sendable (UploadDiagnostics) -> Void

    init(
        onResult: @escaping @Sendable (GatewayScanResult) -> Void,
        onDiagnostics: @escaping @Sendable (UploadDiagnostics) -> Void
    ) {
        self.onResult = onResult
        self.onDiagnostics = onDiagnostics
    }

    func onScanResult(_ result: GatewayScanResult) { onResult(result) }
    func onUploadDiagnostics(_ diagnostics: UploadDiagnostics) { onDiagnostics(diagnostics) }
}

struct DiscoveredDevice: Identifiable, Equatable {
    let peripheralId: UUID
    var lastServiceUUID: String
    var lastServiceDataBytes: Int
    var lastRSSI: Int
    let firstSeen: Date
    var lastSeen: Date
    var sightingCount: Int

    var id: UUID { peripheralId }
}
