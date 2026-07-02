import SwiftUI
import UIKit
import HubbleGatewaySDK

struct GatewaySection: View {
    @Bindable var model: AppModel
    @State private var copiedAt: Date?

    var body: some View {
        StatusRow(
            label: "State",
            value: model.controller.initializationState.rawValue,
            tone: tone(for: model.controller.initializationState)
        )
        StatusRow(
            label: "Scanning",
            value: model.controller.isScanning ? "yes" : "no",
            tone: model.controller.isScanning ? .ok : .neutral
        )

        gatewayIdRow

        Button(model.controller.isScanning ? "Stop" : "Start") {
            model.controller.isScanning ? model.stop() : model.start()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)

        Toggle(isOn: Binding(
            get: { model.controller.isActiveScanning },
            set: { model.setActiveScanning($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active mode")
                Text("Forces fast cadence (60 s upload, 30 s dedup, 10 m GPS) regardless of detected motion. ⚠️ Higher battery use — leave OFF unless you need maximum freshness.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!model.controller.isScanning)
    }

    @ViewBuilder
    private var gatewayIdRow: some View {
        if let id = model.controller.gatewayId {
            Button {
                UIPasteboard.general.string = id
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let stamp = Date()
                copiedAt = stamp
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    if copiedAt == stamp { copiedAt = nil }
                }
            } label: {
                HStack {
                    Text("Gateway ID")
                        .foregroundStyle(.primary)
                    Spacer()
                    if showingCopied {
                        Label("Copied", systemImage: "checkmark")
                            .labelStyle(.titleAndIcon)
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    } else {
                        Text(id)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "doc.on.doc")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: showingCopied)
            .accessibilityHint("Tap to copy gateway ID")
        } else {
            LabeledContent("Gateway ID") {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private var showingCopied: Bool {
        guard let copiedAt else { return false }
        return Date().timeIntervalSince(copiedAt) < 1.5
    }

    private func tone(for state: InitializationState) -> Tone {
        switch state {
        case .ready: return .ok
        case .initializing: return .neutral
        case .notStarted: return .neutral
        case .failed: return .warn
        }
    }
}
