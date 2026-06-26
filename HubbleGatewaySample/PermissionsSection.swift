import SwiftUI
import HubbleGatewaySDK

struct PermissionsSection: View {
    @Bindable var model: AppModel

    var body: some View {
        StatusRow(
            label: "Bluetooth permission",
            value: model.permissions.bluetooth.rawValue,
            tone: tone(for: model.permissions.bluetooth)
        )
        StatusRow(
            label: "Location",
            value: model.permissions.location.rawValue,
            tone: tone(for: model.permissions.location)
        )
        StatusRow(
            label: "Motion",
            value: model.permissions.motion.rawValue,
            tone: tone(for: model.permissions.motion)
        )
        StatusRow(
            label: "Background-ready",
            value: model.permissions.isReadyForBackground ? "yes" : "no",
            tone: model.permissions.isReadyForBackground ? .ok : .warn
        )

        if !model.permissions.isReadyForBackground {
            Text("Background gateway scanning needs `Location: Always`. iOS requires you to first allow `When in Use`, then escalate to `Always` via Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if model.permissions.motion == .denied || model.permissions.motion == .restricted {
            Text("Motion is denied. The SDK will still run, but won't get walking / running / driving classifications from iOS — it falls back to GPS-speed detection. Less precise transitions, slower stationary→moving switches.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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

    private func tone(for status: MotionAuthorization) -> Tone {
        switch status {
        case .authorized: return .ok
        case .notDetermined: return .neutral
        case .denied, .restricted: return .warn
        }
    }
}
