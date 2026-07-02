import Foundation

struct DiscoveredDevice: Identifiable, Equatable {
    let peripheralId: UUID
    var lastServiceUUID: String
    var lastServiceDataBytes: Int
    var lastRSSI: Int
    let firstSeen: Date
    var lastSeen: Date
    var sightingCount: Int

    var id: UUID { peripheralId }
}
