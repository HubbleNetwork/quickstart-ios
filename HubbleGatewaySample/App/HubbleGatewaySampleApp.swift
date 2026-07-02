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
        HubbleGatewaySDK.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
