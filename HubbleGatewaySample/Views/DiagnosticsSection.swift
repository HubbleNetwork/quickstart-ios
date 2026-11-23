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

/// Demonstrates `HubbleGateway.requestBacklogDrain` — the user-initiated
/// `BGContinuedProcessingTask` (iOS 26+). Shows the task identifier the SDK
/// submits (it must be listed in `Info.plist`) and the outcome of the last
/// attempt, so a rejected request is visible without a debugger.
struct BacklogDrainSection: View {
    @State private var outcome: Outcome?

    private enum Outcome {
        case submitted(Date)
        case failed(String)
    }

    var body: some View {
        LabeledContent("Task identifier") {
            Text(GatewayBackgroundTaskIdentifiers.default.continued)
                .font(.footnote.monospaced())
                .multilineTextAlignment(.trailing)
        }

        if #available(iOS 26.0, *) {
            Button("Drain backlog now") { submit() }
        } else {
            Text("Requires iOS 26 or later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        switch outcome {
        case .submitted(let date):
            Text("Submitted at \(date.formatted(date: .omitted, time: .standard)) — iOS accepted the request.")
                .font(.footnote)
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }

    @available(iOS 26.0, *)
    private func submit() {
        do {
            try HubbleGateway.shared.requestBacklogDrain(
                title: "Uploading gateway data",
                subtitle: "Sending queued packets"
            )
            outcome = .submitted(Date())
        } catch {
            let nsError = error as NSError
            outcome = .failed("Rejected: \(nsError.domain) code \(nsError.code) — \(nsError.localizedDescription)")
        }
    }
}
