import SwiftUI
import HubbleGatewaySDK

struct DiagnosticsSection: View {
    let diagnostics: UploadDiagnostics?

    var body: some View {
        if let d = diagnostics {
            LabeledContent("Pending", value: "\(d.pendingPackets)")
            LabeledContent("Uploading", value: "\(d.uploadingPackets)")
            LabeledContent("Failed", value: "\(d.failedPackets)")
            LabeledContent("Last batch", value: "\(d.lastSuccessfulBatchSize) packets")
            LabeledContent("Last upload") {
                Text(d.lastUploadAt.map { Self.format($0) } ?? "—")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Bytes / 24h", value: ByteCountFormatter.string(fromByteCount: d.bytesUploadedLast24h, countStyle: .file))

            if let err = d.lastUploadError {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        } else {
            Text("Diagnostics will appear after the SDK is started.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static func format(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        return f.localizedString(for: date, relativeTo: .now)
    }
}
