import SwiftUI
import HubbleGatewaySDK

struct PermissionsSection: View {
    let permissions: PermissionStatus

    var body: some View {
        StatusRow(
            label: "Bluetooth permission",
            value: permissions.bluetooth.rawValue,
            tone: tone(for: permissions.bluetooth)
        )
        StatusRow(
            label: "Location",
            value: permissions.location.rawValue,
            tone: tone(for: permissions.location)
        )
        StatusRow(
            label: "Motion",
            value: permissions.motion.rawValue,
            tone: tone(for: permissions.motion)
        )
        StatusRow(
            label: "Background-ready",
            value: permissions.isReadyForBackground ? "yes" : "no",
            tone: permissions.isReadyForBackground ? .ok : .warn
        )

        if !permissions.isReadyForBackground {
            Text("Background gateway scanning needs `Location: Always`. After `When in Use` is granted, iOS shows a one-time in-app prompt to upgrade to `Always`; if that prompt was already declined, the only remaining path is Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if permissions.motion == .denied || permissions.motion == .restricted {
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
