import Foundation
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    @Published var isAuthorized = false
    
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            isAuthorized = false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    func sendRankChangeNotification(_ notification: RankChangeNotification) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Chart Update!"
        content.body = notification.message
        content.sound = .default
        
        // Create a unique identifier
        let identifier = UUID().uuidString
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error sending notification: \(error)")
        }
    }
}
