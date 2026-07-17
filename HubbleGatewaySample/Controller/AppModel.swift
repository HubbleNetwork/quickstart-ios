import Foundation
import Observation
import HubbleGatewaySDK
import UIKit

/// Sample-app UI-flow orchestration. Owns *only* state the sample's
/// SwiftUI views care about (alert bindings, surfaced errors). All SDK
/// interaction goes through ``GatewayController``.
///
/// The single Start flow (permissions FIRST — the SDK never presents a
/// system prompt on its own):
/// 1. Hand off to ``GatewayPermissions/request(...)`` for the
///    BT → WhenInUse → Always → Motion escalation. The explainer closure
///    flips `showAlwaysExplainerAlert` so RootView's `.alert(...)` can
///    present the in-app rationale, and waits for the user to dismiss it.
/// 2. Configure the SDK via the controller (sdkKey only — API base URL
///    is baked into the SDK at build time). No prompts fire here.
/// 3. Call `startScanning()` and map the returned ``ScanStartResult``
///    onto the `startBlocker` UI when something is missing.
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

        // 1. Permissions first — the SDK never prompts on its own, so
        // the host drives BT (no-op if already authorized) → WhenInUse →
        // Always → Motion here. Our explainer closure presents the
        // SwiftUI alert and waits for the user to tap one of the buttons.
        _ = await GatewayPermissions.request(
            presentingAlwaysExplainer: { [weak self] in
                await self?.presentAlwaysExplainerAndAwait() ?? false
            }
        )

        // 2. Bring the SDK up. No permission prompt can fire here — the
        // SDK only consumes whatever was granted above.
        do {
            try controller.configure(HubbleGatewayConfig(sdkKey: DefaultConfig.sdkKey))
            lastError = nil
        } catch {
            lastError = String(describing: error)
            return
        }

        // 3. Start scanning; the result reports exactly what's missing,
        // so the UI doesn't need to re-derive it from PermissionStatus.
        let result = controller.startScanning()
        guard result.didStart else {
            startBlocker = Self.blockerMessage(for: result)
            return
        }

        // Collect warnings instead of assigning startBlocker directly:
        // both can apply at once (no Always + radio off), and the radio
        // check must not hide the background-capability warning.
        var warnings: [String] = []
        if !result.isBackgroundCapable {
            warnings.append("Scanning started, but Location is not set to \"Always\" — it will stop when the app goes to the background. Grant Always in Settings → HubbleGatewaySample → Location.")
        }

        // 4. Radio check, distinct from permissions: the adapter may
        // simply be switched off. The SDK joins the scan automatically
        // when it powers back on; this is purely a UI hint.
        if await controller.waitForBluetoothPoweredOn() == false {
            warnings.append("Bluetooth is turned off. Turn it on in Control Center or Settings — scanning resumes automatically.")
        }
        if !warnings.isEmpty {
            startBlocker = warnings.joined(separator: "\n\n")
        }
    }

    private static func blockerMessage(for result: ScanStartResult) -> String {
        switch result.failureReason {
        case .missingPermissions:
            let names = result.missingPermissions.map { kind -> String in
                switch kind {
                case .bluetooth: return "Bluetooth"
                case .locationWhenInUse, .locationAlways: return "Location"
                case .motion: return "Motion"
                }
            }
            return "Missing permissions: \(names.joined(separator: ", ")). Grant them in Settings → HubbleGatewaySample, then tap Start again."
        case .dataCollectionDisabled:
            return "Data collection is disabled. Re-enable it to start scanning."
        case .notReady, .none:
            return "The SDK is not ready. Check the configuration and try again."
        }
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
