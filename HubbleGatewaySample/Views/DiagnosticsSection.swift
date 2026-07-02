import SwiftUI
import HubbleGatewaySDK

struct DiagnosticsSection: View {
    let diagnostics: UploadDiagnostics?

    var body: some View {
        if let d = diagnostics {
            LabeledContent("Uploaded last 24 h", value: Self.formatKB(d.bytesUploadedLast24h))
            LabeledContent("Last packets uploaded", value: Self.formatTime(d.lastUploadAt))
            LabeledContent("Last logs uploaded", value: Self.formatTime(d.lastLogsUploadAt))

            if let err = d.lastUploadError {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        } else {
            Text("Diagnostics will appear after the SDK is started.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static func formatKB(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        return String(format: "%.1f kB", kb)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static func formatTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return timeFormatter.string(from: date)
    }
}
