import SwiftUI
import HubbleGatewaySDK

/// Live list of BLE peripherals the SDK has surfaced via `ScanListener`.
/// One row per peripheral; updated on every sighting (rolling RSSI,
/// last seen). The "Clear list" button empties the local list only —
/// the SDK's persistent scan buffer is untouched, and the next sighting
/// repopulates the list.
struct BleDevicesSection: View {
    let devices: [DiscoveredDevice]
    let onClear: () -> Void

    var body: some View {
        if devices.isEmpty {
            Text("No advertisements seen yet. Start the gateway and wait for a beacon in range.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(devices) { device in
                DeviceRow(device: device)
            }
            Button(role: .destructive, action: onClear) {
                Label("Clear list", systemImage: "trash")
            }
        }
    }
}

private struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(device.peripheralId.uuidString)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)

            Text("\(device.lastRSSI) dBm")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(device.lastServiceUUID, systemImage: "antenna.radiowaves.left.and.right")
                Text("\(device.lastServiceDataBytes) B")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("Last seen at \(Self.timeFormatter.string(from: device.lastSeen))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
