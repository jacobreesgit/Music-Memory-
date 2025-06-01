import Foundation
import MediaPlayer
import SwiftData
import UIKit

@MainActor
class MediaLibraryManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var loadProgress: Double = 0
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func checkAuthorization() async {
        let status = await MPMediaLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            let granted = await MPMediaLibrary.requestAuthorization()
            isAuthorized = (granted == .authorized)
        default:
            isAuthorized = false
        }
    }
    
    func performInitialLoad() async throws {
        guard isAuthorized else {
            throw MediaLibraryError.notAuthorized
        }
        
        isLoading = true
        loadProgress = 0
        
        defer { isLoading = false }
        
        // Check if we've already done the initial load
        let descriptor = FetchDescriptor<TrackedSong>()
        let existingSongs = try await modelContext.fetch(descriptor)
        
        if !existingSongs.isEmpty {
            print("Initial load already completed, skipping...")
            return
        }
        
        // Fetch all songs from the media library
        let query = MPMediaQuery.songs()
        guard let items = query.items else {
            print("No songs found in media library")
            return
        }
        
        print("Found \(items.count) songs in media library")
        
        let totalItems = Double(items.count)
        
        for (index, item) in items.enumerated() {
            // Update progress every 50 items for better responsiveness
            if index % 50 == 0 {
                loadProgress = Double(index) / totalItems
                // Yield control to prevent UI blocking
                await Task.yield()
            }
            
            // Skip items without required properties
            guard let title = item.title,
                  let artist = item.artist else {
                continue
            }
            
            let persistentID = item.persistentID
            
            // ✅ Skip artwork during initial load to avoid color profile errors
            // Artwork will be loaded lazily when needed in the UI
            
            // Create TrackedSong without artwork
            let trackedSong = TrackedSong(
                persistentID: persistentID,
                title: title,
                artist: artist,
                albumTitle: item.albumTitle,
                baselinePlayCount: item.playCount
                // artworkData parameter omitted - will use default nil value
            )
            
            modelContext.insert(trackedSong)
            
            // Save in smaller batches for better performance
            if index % 50 == 0 {
                try await modelContext.save()
            }
        }
        
        // Final save
        try await modelContext.save()
        loadProgress = 1.0
        
        print("Initial load completed. Imported \(items.count) songs.")
    }
    
    // ✅ Method to load artwork for a specific song when needed
    func loadArtworkForSong(_ song: TrackedSong) async {
        guard song.artworkData == nil else { return } // Already has artwork
        
        let query = MPMediaQuery.songs()
        guard let items = query.items?.first(where: { $0.persistentID == song.persistentID }),
              let artwork = items.artwork else { return }
        
        let artworkData = await safeProcessArtwork(artwork)
        
        await MainActor.run {
            song.artworkData = artworkData
            do {
                try modelContext.save()
            } catch {
                print("Error saving artwork: \(error)")
            }
        }
    }
    
    private func safeProcessArtwork(_ artwork: MPMediaItemArtwork) async -> Data? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    let targetSize = CGSize(width: 100, height: 100)
                    
                    guard let image = artwork.image(at: targetSize) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Simple JPEG conversion with lower quality
                    let data = image.jpegData(compressionQuality: 0.5)
                    continuation.resume(returning: data)
                }
            }
        }
    }
}

enum MediaLibraryError: LocalizedError {
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Media library access not authorized"
        }
    }
}
