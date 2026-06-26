import SwiftUI
import HubbleGatewaySDK

struct RootView: View {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    PermissionsSection(model: model)
                }

                Section("Configuration") {
                    ConfigSection(model: model)
                }

                Section("Gateway") {
                    GatewaySection(model: model)
                }

                Section("Upload") {
                    DiagnosticsSection(diagnostics: model.lastDiagnostics)
                }

                Section("Location") {
                    LocationSection(fix: model.lastLocation, diagnostics: model.lastDiagnostics)
                }

                Section("Devices in range") {
                    BleDevicesSection(devices: model.discoveredDevices)
                }

                if let error = model.lastError {
                    Section("Last error") {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Delete all data", role: .destructive) { model.deleteAll() }
                }
            }
            .navigationTitle("Hubble Gateway")
            .onAppear { model.refresh() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { model.onSceneBecameActive() }
            }
            .alert(
                "Allow background access",
                isPresented: $model.showAlwaysExplainerAlert,
                actions: {
                    Button("Open Settings") { model.confirmAlwaysExplainer() }
                    Button("Not now", role: .cancel) { model.showAlwaysExplainerAlert = false }
                },
                message: {
                    Text("The gateway relays Bluetooth beacons even when the app is in the background or your screen is locked. iOS needs Location set to “Always” for that to work. Tap Open Settings → Location → Always.")
                }
            )
            .alert(
                "Can't start",
                isPresented: Binding(
                    get: { model.startBlocker != nil },
                    set: { if !$0 { model.startBlocker = nil } }
                ),
                presenting: model.startBlocker
            ) { _ in
                Button("Open Settings") { model.openSettingsForStartBlocker() }
                Button("OK", role: .cancel) { model.startBlocker = nil }
            } message: { message in
                Text(message)
            }
        }
    }
}
