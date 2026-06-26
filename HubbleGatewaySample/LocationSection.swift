import SwiftUI
import HubbleGatewaySDK

/// Last cached fix + the SDK's per-cycle location-eligibility status.
/// Together this gives a quick "is location working at all?" read.
struct LocationSection: View {
    let fix: LocationFix?
    let diagnostics: UploadDiagnostics?

    var body: some View {
        if let fix {
            LabeledContent("Last fix at", value: Self.timeFormatter.string(from: fix.timestamp))
            LabeledContent("Accuracy", value: String(format: "%.0f m", fix.horizontalAccuracy))
        } else {
            LabeledContent("Last fix at", value: "—")
            LabeledContent("Accuracy", value: "—")
        }

        if let d = diagnostics {
            Text(statusText(for: d))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Mirror of the SDK's per-cycle log line so the user sees the same
    /// reasoning here as in Console.app — useful for debugging "why
    /// isn't anything being uploaded?".
    private func statusText(for d: UploadDiagnostics) -> String {
        let active = d.pendingLocations + d.uploadingLocations + d.failedLocations
        if active == 0 {
            // Pending/uploading/failed all 0 — either nothing captured
            // yet, or everything successfully uploaded already (rows
            // sit as status=UPLOADED until the 7-day retention prune).
            if let last = d.lastLocationsUploadAt {
                return "All captured fixes uploaded. Last batch shipped at \(Self.timeFormatter.string(from: last))."
            }
            return "No location fixes captured yet (stationary device or stream not yet delivered a fix)."
        }
        if d.pendingLocations == 0 && d.failedLocations > 0 {
            return "\(d.failedLocations) failed row(s) in backoff. Pending 0, uploading \(d.uploadingLocations)."
        }
        if d.pendingLocations == 0 && d.uploadingLocations > 0 {
            return "\(d.uploadingLocations) stuck UPLOADING — will reset next cycle."
        }
        return "Locations queued: \(d.pendingLocations) pending · \(d.uploadingLocations) uploading · \(d.failedLocations) failed."
    }
}
