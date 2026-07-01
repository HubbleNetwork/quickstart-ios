import Foundation
import Observation
import HubbleGatewaySDK
import UIKit

/// Reference integration of `HubbleGatewaySDK` for SwiftUI hosts. Copy this
/// file into your own app — it has no sample-app-specific concerns:
///
/// - Mirrors every SDK state field as `@Observable` properties so SwiftUI
///   views can bind directly.
/// - Polls the SDK on a 5 s timer and on `UIApplication.didBecomeActive` so
///   permission flips made in Settings surface without the user reopening
///   the app.
/// - Bridges ``ScanListener`` callbacks onto the `@MainActor` and maintains
///   a deduped ``DiscoveredDevice`` list keyed on peripheral identifier.
///
/// Anything UI-flow related (alerts, blocker text, text-field state) lives
/// in ``AppModel`` next door — keep that boundary when adopting.
@MainActor
@Observable
final class GatewayController {

    // MARK: - SDK state mirrors

    private(set) var permissions: PermissionStatus = GatewayPermissions.currentStatus()
    private(set) var initializationState: InitializationState = .notStarted
    private(set) var isScanning: Bool = false
    private(set) var isActiveScanning: Bool = false
    private(set) var gatewayId: String?
    private(set) var lastLocation: LocationFix?
    private(set) var lastDiagnostics: UploadDiagnostics?
    private(set) var isBluetoothPoweredOn: Bool = false

    // MARK: - Derived state

    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private var deviceIndex: [UUID: DiscoveredDevice] = [:]

    // MARK: - Internals

    private var pollTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?
    private var scanCollector: ScanCollector?

    init() {
        installLifecycleObservers()
        refresh()
        startPolling()
    }

    // No deinit cleanup needed — controller lives for the lifetime of the
    // host app (its `AppModel` owner is held by `RootView`'s `@State`).

    // MARK: - SDK lifecycle

    /// Starts the SDK with the given config and attaches the scan-collector
    /// bridge. Subsequent calls (after the first) are no-ops on the SDK
    /// side — re-attaching the bridge is idempotent.
    func configure(_ config: HubbleGatewayConfig) throws {
        if HubbleGatewaySDK.shared.initializationState != .ready {
            try HubbleGatewaySDK.shared.start(config: config)
        }
        attachScanCollector()
        refresh()
    }

    func startScanning() {
        HubbleGatewaySDK.shared.startScanning()
        refresh()
    }

    func stopScanning() {
        HubbleGatewaySDK.shared.stopScanning()
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

    func deleteAll() {
        HubbleGatewaySDK.shared.deleteAllData()
        deviceIndex = [:]
        discoveredDevices = []
        refresh()
    }

    func registerNow() async throws {
        try await HubbleGatewaySDK.shared.registerIfNeeded()
        refresh()
    }

    /// Pull the latest snapshot from the SDK into the observable mirrors.
    /// Cheap — no I/O, just property reads.
    func refresh() {
        permissions = GatewayPermissions.currentStatus()
        initializationState = HubbleGatewaySDK.shared.initializationState
        isScanning = HubbleGatewaySDK.shared.isScanning
        isActiveScanning = HubbleGatewaySDK.shared.isActiveScanningOverride
        gatewayId = HubbleGatewaySDK.shared.gatewayId
        lastLocation = HubbleGatewaySDK.shared.lastLocation
        isBluetoothPoweredOn = HubbleGatewaySDK.shared.isBluetoothPoweredOn

        Task {
            if let snap = try? await HubbleGatewaySDK.shared.uploadDiagnostics() {
                lastDiagnostics = snap
            }
        }
    }

    // MARK: - Wait helpers for start-flow callers

    /// Polls `isBluetoothPoweredOn` until it flips true or `timeout`
    /// elapses. `CBCentralManager.state` is only readable after the SDK
    /// spins one up, so this lets callers wait for the radio to be
    /// usable before starting the scan.
    func waitForBluetoothPoweredOn(timeout: TimeInterval = 8) async -> Bool {
        let stepMs: UInt64 = 100
        let maxIterations = Int(timeout * 1000) / Int(stepMs)
        for _ in 0..<maxIterations {
            if HubbleGatewaySDK.shared.isBluetoothPoweredOn { return true }
            try? await Task.sleep(nanoseconds: stepMs * 1_000_000)
        }
        return HubbleGatewaySDK.shared.isBluetoothPoweredOn
    }

    // MARK: - Scan listener bridge

    private func attachScanCollector() {
        guard scanCollector == nil else { return }
        let collector = ScanCollector { [weak self] result in
            Task { @MainActor in self?.ingest(result) }
        } onDiagnostics: { [weak self] diagnostics in
            Task { @MainActor in self?.lastDiagnostics = diagnostics }
        }
        HubbleGatewaySDK.shared.addScanListener(collector)
        scanCollector = collector
    }

    private func ingest(_ result: GatewayScanResult) {
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

    // MARK: - Polling + lifecycle

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.refresh()
            }
        }
    }

    private func installLifecycleObservers() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
}

/// Bridge from `ScanListener` protocol to the @MainActor controller.
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
