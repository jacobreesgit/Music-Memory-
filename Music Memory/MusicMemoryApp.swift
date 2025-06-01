import SwiftUI
import SwiftData

@main
struct MusicMemoryApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                TrackedSong.self,
                PlayEvent.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView(modelContext: modelContainer.mainContext)
                .modelContainer(modelContainer)
        }
    }
}
