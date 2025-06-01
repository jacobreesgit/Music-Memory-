import Foundation
import MediaPlayer
import SwiftData
import UserNotifications
import UIKit

@MainActor
class NowPlayingTracker: ObservableObject {
    private let modelContext: ModelContext
    private let notificationManager: NotificationManager
    private var musicPlayer: MPMusicPlayerController
    private var lastKnownItem: MPMediaItem?
    private var lastKnownPlayCount: [UInt64: Int] = [:]
    
    @Published var isTracking = false
    
    init(modelContext: ModelContext, notificationManager: NotificationManager) {
        self.modelContext = modelContext
        self.notificationManager = notificationManager
        self.musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        
        musicPlayer.beginGeneratingPlaybackNotifications()
        isTracking = true
    }
    
    @objc private func nowPlayingItemChanged() {
        Task { @MainActor in
            await checkForPlayCountChange()
        }
    }
    
    private func checkForPlayCountChange() async {
        guard let currentItem = musicPlayer.nowPlayingItem else { return }
        
        let persistentID = currentItem.persistentID
        let currentPlayCount = currentItem.playCount
        
        // Check if this is a new song or if play count increased
        if let lastCount = lastKnownPlayCount[persistentID] {
            if currentPlayCount > lastCount {
                // Play count increased - log the play
                await logPlay(for: currentItem)
            }
        } else {
            // First time seeing this song in this session
            lastKnownPlayCount[persistentID] = currentPlayCount
        }
        
        // Update last known values
        lastKnownItem = currentItem
        lastKnownPlayCount[persistentID] = currentPlayCount
    }
    
    private func logPlay(for item: MPMediaItem) async {
        let persistentID = item.persistentID
        
        // Find the tracked song
        let descriptor = FetchDescriptor<TrackedSong>(
            predicate: #Predicate { $0.persistentID == persistentID }
        )
        
        do {
            let songs = try await modelContext.fetch(descriptor)
            guard let song = songs.first else {
                // Song not in our database yet - add it
                await addNewSong(item)
                return
            }
            
            // Create play event
            let playEvent = PlayEvent(song: song)
            modelContext.insert(playEvent)
            
            // Update local play count
            song.localPlayCount += 1
            
            // Save changes
            try await modelContext.save()
            
            // Check for rank changes and send notification if needed
            await updateRankingsAndNotify(for: song)
            
        } catch {
            print("Error logging play: \(error)")
        }
    }
    
    private func addNewSong(_ item: MPMediaItem) async {
        guard let title = item.title,
              let artist = item.artist else { return }
        
        // ✅ Use improved artwork processing
        var artworkData: Data?
        if let artwork = item.artwork {
            artworkData = await processArtwork(artwork)
        }
        
        let trackedSong = TrackedSong(
            persistentID: item.persistentID,
            title: title,
            artist: artist,
            albumTitle: item.albumTitle,
            baselinePlayCount: item.playCount - 1, // Subtract 1 since we're about to log a play
            artworkData: artworkData
        )
        
        modelContext.insert(trackedSong)
        
        // Create the play event
        let playEvent = PlayEvent(song: trackedSong)
        modelContext.insert(playEvent)
        trackedSong.localPlayCount = 1
        
        do {
            try await modelContext.save()
            await updateRankingsAndNotify(for: trackedSong)
        } catch {
            print("Error adding new song: \(error)")
        }
    }
    
    // ✅ Much simpler artwork processing
    private func processArtwork(_ artwork: MPMediaItemArtwork) async -> Data? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    let targetSize = CGSize(width: 100, height: 100)
                    
                    // Try to get the image, but if it fails, just return nil
                    guard let image = artwork.image(at: targetSize) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Simple JPEG conversion with lower quality to avoid color profile issues
                    let data = image.jpegData(compressionQuality: 0.5)
                    continuation.resume(returning: data)
                }
            }
        }
    }
    
    private func updateRankingsAndNotify(for changedSong: TrackedSong) async {
        // Fetch all songs and calculate new rankings
        let descriptor = FetchDescriptor<TrackedSong>(
            sortBy: [SortDescriptor(\.totalPlayCount, order: .reverse)]
        )
        
        do {
            let allSongs = try await modelContext.fetch(descriptor)
            
            // ✅ Update rankings in batches to avoid blocking
            let batchSize = 50
            for i in stride(from: 0, to: allSongs.count, by: batchSize) {
                let endIndex = min(i + batchSize, allSongs.count)
                let batch = Array(allSongs[i..<endIndex])
                
                for (localIndex, song) in batch.enumerated() {
                    song.previousRank = song.lastKnownRank
                    song.lastKnownRank = i + localIndex + 1
                }
                
                // Yield control every batch
                await Task.yield()
            }
            
            try await modelContext.save()
            
            // Check if our changed song moved in rankings
            if let newRank = changedSong.lastKnownRank,
               let oldRank = changedSong.previousRank,
               newRank != oldRank {
                
                let notification = RankChangeNotification(
                    songTitle: changedSong.title,
                    artist: changedSong.artist,
                    newRank: newRank,
                    oldRank: oldRank
                )
                
                await notificationManager.sendRankChangeNotification(notification)
            }
            
        } catch {
            print("Error updating rankings: \(error)")
        }
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}

struct RankChangeNotification {
    let songTitle: String
    let artist: String
    let newRank: Int
    let oldRank: Int
    
    var message: String {
        if newRank < oldRank {
            return "🎵 '\(songTitle)' by \(artist) just jumped to #\(newRank)!"
        } else {
            return "📉 '\(songTitle)' by \(artist) dropped to #\(newRank)"
        }
    }
}
