import SwiftUI
import HubbleGatewaySDK

@main
struct HubbleGatewaySampleApp: App {

    init() {
        // MUST run before launch finishes — registers BG task handlers.
        HubbleGatewaySDK.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
