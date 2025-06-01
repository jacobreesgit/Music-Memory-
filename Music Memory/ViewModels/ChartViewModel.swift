import Foundation
import SwiftData
import SwiftUI

@MainActor
class ChartViewModel: ObservableObject {
    @Published var songs: [TrackedSong] = []
    @Published var selectedFilter: TimeFilter = .allTime
    @Published var isLoading = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func loadSongs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create fetch descriptor based on selected filter
            let descriptor = FetchDescriptor<TrackedSong>()
            var allSongs = try modelContext.fetch(descriptor)
            
            // Sort by play count for the selected time filter
            allSongs.sort { song1, song2 in
                song1.getPlayCount(for: selectedFilter) > song2.getPlayCount(for: selectedFilter)
            }
            
            // Filter out songs with zero plays for non-all-time filters
            if selectedFilter != .allTime {
                allSongs = allSongs.filter { $0.getPlayCount(for: selectedFilter) > 0 }
            }
            
            // Update rankings based on current filter
            for (index, song) in allSongs.enumerated() {
                song.previousRank = song.lastKnownRank
                song.lastKnownRank = index + 1
            }
            
            try modelContext.save()
            
            // Update published array with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                self.songs = Array(allSongs.prefix(100)) // Show top 100
            }
            
        } catch {
            print("Error loading songs: \(error)")
        }
    }
    
    func changeFilter(to filter: TimeFilter) {
        guard filter != selectedFilter else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedFilter = filter
        }
        
        Task {
            await loadSongs()
        }
    }
}
