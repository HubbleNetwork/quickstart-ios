import SwiftUI

enum Tone {
    case ok, warn, neutral

    var color: Color {
        switch self {
        case .ok: return .green
        case .warn: return .orange
        case .neutral: return .secondary
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    var tone: Tone = .neutral

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(tone.color).monospacedDigit()
        }
    }
}
