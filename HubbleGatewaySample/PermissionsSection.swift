import SwiftUI
import HubbleGatewaySDK

struct PermissionsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        StatusRow(
            label: "Bluetooth",
            value: model.permissions.bluetooth.rawValue,
            tone: tone(for: model.permissions.bluetooth)
        )
        StatusRow(
            label: "Location",
            value: model.permissions.location.rawValue,
            tone: tone(for: model.permissions.location)
        )
        StatusRow(
            label: "Background-ready",
            value: model.permissions.isReadyForBackground ? "yes" : "no",
            tone: model.permissions.isReadyForBackground ? .ok : .warn
        )

        if !model.permissions.isReadyForBackground {
            Text("Background gateway scanning needs `Location: Always`. iOS requires you to first request `When in Use`, then escalate to `Always`.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Button("Open Settings") { model.openSettings() }
    }

    private func tone(for status: BluetoothAuthorization) -> Tone {
        switch status {
        case .authorized: return .ok
        case .notDetermined: return .neutral
        case .denied, .restricted, .unknown: return .warn
        }
    }

    private func tone(for status: LocationAuthorization) -> Tone {
        switch status {
        case .authorizedAlways: return .ok
        case .authorizedWhenInUse: return .warn
        case .notDetermined: return .neutral
        case .denied, .restricted: return .warn
        }
    }
}
