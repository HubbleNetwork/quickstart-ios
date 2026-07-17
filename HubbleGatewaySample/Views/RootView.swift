import SwiftUI
import HubbleGatewaySDK

struct RootView: View {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    PermissionsSection(permissions: model.controller.permissions)
                }

                Section("Gateway") {
                    GatewaySection(model: model)
                }

                Section("Upload") {
                    DiagnosticsSection(diagnostics: model.controller.lastDiagnostics)
                }

                Section("Location") {
                    LocationSection(
                        fix: model.controller.lastLocation,
                        diagnostics: model.controller.lastDiagnostics
                    )
                }

                Section("Devices in range") {
                    BleDevicesSection(
                        devices: model.controller.discoveredDevices,
                        onClear: { model.controller.clearDiscoveredDevices() }
                    )
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

                Section {
                    HStack {
                        Spacer()
                        Text(Self.buildFooter)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Hubble Gateway")
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { model.onSceneBecameActive() }
            }
            .alert(
                "Allow background access",
                isPresented: $model.showAlwaysExplainerAlert,
                actions: {
                    Button(model.alwaysEscalationNeedsSettings ? "Open Settings" : "Continue") {
                        model.resolveAlwaysExplainer(escalate: true)
                    }
                    Button("Not now", role: .cancel) {
                        model.resolveAlwaysExplainer(escalate: false)
                    }
                },
                message: {
                    Text(
                        model.alwaysEscalationNeedsSettings
                        ? "The gateway relays Bluetooth beacons even when the app is in the background or your screen is locked. iOS needs Location set to “Always” for that to work. Tap Open Settings → Location → Always."
                        : "The gateway relays Bluetooth beacons even when the app is in the background or your screen is locked. iOS needs Location set to “Always” for that to work. Tap Continue, then choose “Change to Always Allow” on the system prompt."
                    )
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

    /// "v0.1.8 (8)" — reads `CFBundleShortVersionString` +
    /// `CFBundleVersion` from `Info.plist`, populated at build time
    /// from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
    private static let buildFooter: String = {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info["CFBundleVersion"] as? String) ?? "?"
        return "v\(version) (\(build))"
    }()
}
