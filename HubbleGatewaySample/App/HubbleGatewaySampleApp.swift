import SwiftUI
import HubbleGatewaySDK

@main
struct HubbleGatewaySampleApp: App {

    init() {
        // Catch missing Info.plist keys / background modes / BGTask IDs
        // *before* `registerBackgroundTasks()` raises an NSException on a
        // misconfigured host. The check is a pure Bundle read — cheap.
        #if DEBUG
        let check = HubbleGatewaySDK.validateIntegration()
        if !check.isValid {
            assertionFailure(check.description)
        }
        #endif

        // MUST run before launch finishes — registers BG task handlers.
        // The configProvider makes the gateway survive process death: when
        // iOS relaunches the app in the background (BGTask fire, BLE
        // restoration) and scanning was active before the kill, the SDK
        // auto-runs start(config:) + startScanning() from this closure.
        // No permission prompt can fire from this path — permissions are
        // always already determined on a background relaunch, and the SDK
        // never presents prompts itself (see AppModel.runStart()).
        HubbleGatewaySDK.registerBackgroundTasks {
            HubbleGatewayConfig(sdkKey: DefaultConfig.sdkKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
