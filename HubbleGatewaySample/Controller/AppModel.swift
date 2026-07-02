import Foundation
import Observation
import HubbleGatewaySDK
import UIKit

/// Sample-app UI-flow orchestration. Owns *only* state the sample's
/// SwiftUI views care about (alert bindings, surfaced errors). All SDK
/// interaction goes through ``GatewayController``.
///
/// The single Start flow:
/// 1. Configure the SDK via the controller (sdkKey only — API base URL
///    is baked into the SDK at build time).
/// 2. Hand off to ``GatewayPermissions/request(presentingAlwaysExplainer:_:_:_:)``
///    for the BT → WhenInUse → Always escalation. The explainer closure
///    flips `showAlwaysExplainerAlert` so RootView's `.alert(...)` can
///    present the in-app rationale, and waits for the user to dismiss it.
/// 3. Once permissions are usable, kick off `startScanning()`.
@MainActor
@Observable
final class AppModel {

    let controller = GatewayController()

    // UI-flow state — nothing here belongs in the SDK.
    var showAlwaysExplainerAlert: Bool = false
    var startBlocker: String?
    var lastError: String?

    /// Continuation resumed when the user dismisses the Always-explainer
    /// alert. Lives here (not in the controller) because dismissal is a
    /// UI event, not an SDK event.
    private var alwaysExplainerContinuation: CheckedContinuation<Bool, Never>?

    // MARK: - Start flow

    /// One-tap Start: configure the SDK, run the permission escalation,
    /// then begin scanning. Idempotent — calling while already scanning
    /// is a no-op.
    func start() {
        Task { await runStart() }
    }

    private func runStart() async {
        controller.refresh()
        if controller.isScanning { return }

        do {
            try controller.configure(HubbleGatewayConfig(sdkKey: DefaultConfig.sdkKey))
            lastError = nil
        } catch {
            lastError = String(describing: error)
            return
        }

        // Wait for the SDK's CBCentralManager to report adapter state.
        // The system BT permission prompt fires during this window.
        if await controller.waitForBluetoothPoweredOn() == false {
            startBlocker = "Bluetooth is turned off. Turn it on in Control Center or Settings, then tap Start again."
            return
        }

        // Drives BT (no-op if already authorized) → WhenInUse → Always.
        // Our explainer closure presents the SwiftUI alert and waits for
        // the user to tap one of the buttons.
        let status = await GatewayPermissions.request(
            presentingAlwaysExplainer: { [weak self] in
                await self?.presentAlwaysExplainerAndAwait() ?? false
            }
        )

        guard status.location != .denied, status.location != .restricted else {
            startBlocker = "Location access is denied. Grant it in Settings → HubbleGatewaySample → Location, then tap Start again."
            return
        }

        controller.startScanning()
    }

    /// Sets `showAlwaysExplainerAlert = true` and suspends until the
    /// alert dismissal handler resumes the continuation with the user's
    /// choice (true = open Settings, false = not now).
    private func presentAlwaysExplainerAndAwait() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            alwaysExplainerContinuation = cont
            showAlwaysExplainerAlert = true
        }
    }

    /// Called from RootView's alert buttons.
    func resolveAlwaysExplainer(openSettings: Bool) {
        showAlwaysExplainerAlert = false
        let cont = alwaysExplainerContinuation
        alwaysExplainerContinuation = nil
        cont?.resume(returning: openSettings)
    }

    func stop() {
        controller.stopScanning()
    }

    func deleteAll() {
        controller.deleteAll()
    }

    func setActiveScanning(_ enabled: Bool) {
        controller.setActiveScanning(enabled)
    }

    func registerNow() {
        Task {
            do {
                try await controller.registerNow()
                lastError = nil
            } catch {
                lastError = String(describing: error)
            }
        }
    }

    // MARK: - Settings round-trip

    func openSettingsForStartBlocker() {
        startBlocker = nil
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func onSceneBecameActive() {
        controller.refresh()
    }
}
