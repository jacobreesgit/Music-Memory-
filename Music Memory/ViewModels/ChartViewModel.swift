import Foundation
import SwiftData
import SwiftUI

@MainActor
class ChartViewModel: ObservableObject {
    @Published var songs: [TrackedSong] = []
    @Published var selectedFilter: TimeFilter = .allTime
    @Published var isLoading = false
    
    private let modelContext: ModelContext
    private var loadTask: Task<Void, Never>?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func loadSongs() async {
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            // ✅ Direct call without unnecessary try-catch
            await loadSongsOptimized()
        }
        
        await loadTask?.value
    }
    
    private func loadSongsOptimized() async {
        // Capture the current filter to avoid actor isolation issues
        let currentFilter = selectedFilter
        
        do {
            // Create fetch descriptor and fetch songs on main actor
            let descriptor = FetchDescriptor<TrackedSong>()
            let allSongs = try await modelContext.fetch(descriptor)
            
            // Process songs in background while staying on main actor for model access
            let sortedSongs = await processAndSortSongs(allSongs, filter: currentFilter)
            
            // ✅ Yield control periodically during ranking updates
            await updateRankings(for: Array(sortedSongs.prefix(100)))
            
            // Update UI with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                self.songs = Array(sortedSongs.prefix(100)) // Show top 100
            }
            
        } catch {
            print("Error in loadSongsOptimized: \(error)")
        }
    }
    
    private func processAndSortSongs(_ allSongs: [TrackedSong], filter: TimeFilter) async -> [TrackedSong] {
        return await withCheckedContinuation { continuation in
            Task {
                // ✅ Process sorting in background
                let songsWithCounts = allSongs.compactMap { song -> (TrackedSong, Int)? in
                    let playCount = song.getPlayCount(for: filter)
                    // Filter out songs with zero plays for non-all-time filters
                    if filter != .allTime && playCount == 0 {
                        return nil
                    }
                    return (song, playCount)
                }
                
                // Sort by pre-calculated counts
                let sortedPairs = songsWithCounts.sorted { $0.1 > $1.1 }
                let sortedSongs = sortedPairs.map { $0.0 }
                
                continuation.resume(returning: sortedSongs)
            }
        }
    }
    
    private func updateRankings(for songs: [TrackedSong]) async {
        // Update rankings in batches to avoid blocking
        let batchSize = 20
        
        for i in stride(from: 0, to: songs.count, by: batchSize) {
            let endIndex = min(i + batchSize, songs.count)
            let batch = Array(songs[i..<endIndex])
            
            for (localIndex, song) in batch.enumerated() {
                song.previousRank = song.lastKnownRank
                song.lastKnownRank = i + localIndex + 1
            }
            
            // Yield control every batch to keep UI responsive
            await Task.yield()
        }
        
        do {
            try await modelContext.save()
        } catch {
            print("Error saving rankings: \(error)")
        }
    }
    
    func changeFilter(to filter: TimeFilter) {
        guard filter != selectedFilter else { return }
        
        // Cancel any existing load
        loadTask?.cancel()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedFilter = filter
        }
        
        Task {
            await loadSongs()
        }
    }
    
    deinit {
        loadTask?.cancel()
    }
}
