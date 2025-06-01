import Foundation
import SwiftData

@Model
final class PlayEvent {
    var timestamp: Date
    var song: TrackedSong?
    
    init(timestamp: Date = Date(), song: TrackedSong) {
        self.timestamp = timestamp
        self.song = song
    }
}
