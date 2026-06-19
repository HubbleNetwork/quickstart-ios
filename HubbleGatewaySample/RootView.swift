import SwiftUI
import HubbleGatewaySDK

struct RootView: View {
    @State private var model = AppModel()

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

                Section("Upload diagnostics") {
                    DiagnosticsSection(diagnostics: model.lastDiagnostics)
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
        }
    }
}
