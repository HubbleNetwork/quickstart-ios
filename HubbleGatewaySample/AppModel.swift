import Foundation
import Observation
import HubbleGatewaySDK
import UIKit

/// Glue between the SDK's `@MainActor` façade and SwiftUI views. Polls the
/// SDK on a timer and exposes everything the UI renders.
@MainActor
@Observable
final class AppModel {

    // Permission state
    var permissions: PermissionStatus = GatewayPermissions.currentStatus()

    // SDK state mirrored for the UI
    var initializationState: InitializationState = .notStarted
    var isScanning: Bool = false
    var gatewayId: String?
    var lastDiagnostics: UploadDiagnostics?
    var lastError: String?

    // API base URL is user-overridable; the SDK key is baked into
    // `DefaultConfig` and intentionally NOT surfaced in the UI.
    var apiBaseURLString: String {
        didSet { UserDefaults.standard.set(apiBaseURLString, forKey: "demo.apiBase") }
    }

    private var pollTask: Task<Void, Never>?

    init() {
        // One-time migration: drop a stored value that matches an
        // out-of-date default we shipped earlier.
        let legacyDefaults: Set<String> = ["https://api.hubblenetwork.com"]
        if let stored = UserDefaults.standard.string(forKey: "demo.apiBase"),
           legacyDefaults.contains(stored) {
            UserDefaults.standard.removeObject(forKey: "demo.apiBase")
        }
        self.apiBaseURLString = UserDefaults.standard.string(forKey: "demo.apiBase")
            ?? DefaultConfig.apiBaseURLString
        refresh()
        startPolling()
    }

    // MARK: - SDK lifecycle

    func start() {
        guard let url = URL(string: apiBaseURLString) else {
            lastError = "API URL is invalid"
            return
        }
        do {
            let config = HubbleGatewayConfig(
                sdkKey: DefaultConfig.sdkKey,
                apiBaseURL: url
            )
            try HubbleGatewaySDK.shared.start(config: config)
            HubbleGatewaySDK.shared.startScanning()
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
        refresh()
    }

    func stop() {
        HubbleGatewaySDK.shared.stopScanning()
        refresh()
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
        refresh()
    }

    // MARK: - Permissions

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                self?.refresh()
            }
        }
    }

    func refresh() {
        permissions = GatewayPermissions.currentStatus()
        initializationState = HubbleGatewaySDK.shared.initializationState
        isScanning = HubbleGatewaySDK.shared.isScanning
        gatewayId = HubbleGatewaySDK.shared.gatewayId

        Task {
            if let snap = try? await HubbleGatewaySDK.shared.uploadDiagnostics() {
                lastDiagnostics = snap
            }
        }
    }
}
