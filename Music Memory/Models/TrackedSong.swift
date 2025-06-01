import Foundation
import SwiftData
import SwiftUI

@Model
final class TrackedSong {
    @Attribute(.unique)
    var persistentID: UInt64
    
    var title: String
    var artist: String
    var albumTitle: String?
    var baselinePlayCount: Int
    var localPlayCount: Int
    var lastKnownRank: Int?
    var previousRank: Int?
    var artworkData: Data?
    
    @Relationship(deleteRule: .cascade, inverse: \PlayEvent.song)
    var playEvents: [PlayEvent] = []
    
    var totalPlayCount: Int {
        baselinePlayCount + localPlayCount
    }
    
    var rankChange: RankChange {
        guard let current = lastKnownRank,
              let previous = previousRank else {
            return .new
        }
        
        if current < previous {
            return .up(previous - current)
        } else if current > previous {
            return .down(current - previous)
        } else {
            return .same
        }
    }
    
    init(persistentID: UInt64,
         title: String,
         artist: String,
         albumTitle: String? = nil,
         baselinePlayCount: Int,
         artworkData: Data? = nil) {
        self.persistentID = persistentID
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.baselinePlayCount = baselinePlayCount
        self.localPlayCount = 0
        self.artworkData = artworkData
    }
    
    func getPlayCount(for filter: TimeFilter) -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        let filteredEvents: [PlayEvent]
        
        switch filter {
        case .allTime:
            filteredEvents = playEvents
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            filteredEvents = playEvents.filter { $0.timestamp >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            filteredEvents = playEvents.filter { $0.timestamp >= monthAgo }
        case .thisYear:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            filteredEvents = playEvents.filter { $0.timestamp >= yearAgo }
        }
        
        if filter == .allTime {
            return totalPlayCount
        } else {
            return filteredEvents.count
        }
    }
}

enum RankChange: Equatable {
    case new
    case up(Int)
    case down(Int)
    case same
    
    var symbol: String {
        switch self {
        case .new:
            return "NEW"
        case .up(let positions):
            return "↑\(positions)"
        case .down(let positions):
            return "↓\(positions)"
        case .same:
            return "–"
        }
    }
    
    // ✅ Fixed: Return SwiftUI Color instead of String
    var color: Color {
        switch self {
        case .new, .up:
            return .green
        case .down:
            return .red
        case .same:
            return .gray
        }
    }
}

enum TimeFilter: String, CaseIterable {
    case allTime = "All Time"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
}
