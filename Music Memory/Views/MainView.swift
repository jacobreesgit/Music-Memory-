import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var mediaLibraryManager: MediaLibraryManager
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var nowPlayingTracker: NowPlayingTracker
    
    @State private var showingPermissionAlert = false
    @State private var setupComplete = false
    
    init(modelContext: ModelContext) {
        let mediaManager = MediaLibraryManager(modelContext: modelContext)
        let notifManager = NotificationManager()
        
        _mediaLibraryManager = StateObject(wrappedValue: mediaManager)
        _notificationManager = StateObject(wrappedValue: notifManager)
        _nowPlayingTracker = StateObject(wrappedValue: NowPlayingTracker(
            modelContext: modelContext,
            notificationManager: notifManager
        ))
    }
    
    var body: some View {
        Group {
            if setupComplete {
                ChartView(modelContext: modelContext)
            } else if mediaLibraryManager.isLoading {
                LoadingView(progress: mediaLibraryManager.loadProgress)
            } else {
                SetupView(
                    mediaLibraryAuthorized: mediaLibraryManager.isAuthorized,
                    notificationsAuthorized: notificationManager.isAuthorized,
                    onRequestMediaAccess: requestMediaAccess,
                    onRequestNotificationAccess: requestNotificationAccess,
                    onContinue: completeSetup
                )
            }
        }
        .task {
            await checkInitialSetup()
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable Media Library access in Settings to use Music Memory.")
        }
    }
    
    private func checkInitialSetup() async {
        // Check if we've already done initial setup
        let descriptor = FetchDescriptor<TrackedSong>(
            fetchLimit: 1
        )
        
        do {
            let existingSongs = try modelContext.fetch(descriptor)
            if !existingSongs.isEmpty {
                // Already set up
                setupComplete = true
                return
            }
        } catch {
            print("Error checking setup status: \(error)")
        }
        
        // Check permissions
        await mediaLibraryManager.checkAuthorization()
        await notificationManager.checkAuthorizationStatus()
    }
    
    private func requestMediaAccess() {
        Task {
            await mediaLibraryManager.checkAuthorization()
            
            if !mediaLibraryManager.isAuthorized {
                showingPermissionAlert = true
            }
        }
    }
    
    private func requestNotificationAccess() {
        Task {
            await notificationManager.requestAuthorization()
        }
    }
    
    private func completeSetup() {
        guard mediaLibraryManager.isAuthorized else {
            showingPermissionAlert = true
            return
        }
        
        Task {
            do {
                try await mediaLibraryManager.performInitialLoad()
                setupComplete = true
            } catch {
                print("Error during initial load: \(error)")
            }
        }
    }
}
