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
        let existingSongs = try modelContext.fetch(descriptor)
        
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
            // Update progress
            loadProgress = Double(index) / totalItems
            
            // Skip items without required properties
            guard let title = item.title,
                  let artist = item.artist else {
                continue
            }
            
            let persistentID = item.persistentID
            
            // Get artwork data if available
            var artworkData: Data?
            if let artwork = item.artwork {
                let targetSize = CGSize(width: 100, height: 100)
                if let image = artwork.image(at: targetSize) {
                    artworkData = image.jpegData(compressionQuality: 0.8)
                }
            }
            
            // Create TrackedSong
            let trackedSong = TrackedSong(
                persistentID: persistentID,
                title: title,
                artist: artist,
                albumTitle: item.albumTitle,
                baselinePlayCount: item.playCount,
                artworkData: artworkData
            )
            
            modelContext.insert(trackedSong)
            
            // Save in batches to avoid memory issues
            if index % 100 == 0 {
                try modelContext.save()
            }
        }
        
        // Final save
        try modelContext.save()
        loadProgress = 1.0
        
        print("Initial load completed. Imported \(items.count) songs.")
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
