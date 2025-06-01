import SwiftUI

struct SetupView: View {
    let mediaLibraryAuthorized: Bool
    let notificationsAuthorized: Bool
    let onRequestMediaAccess: () -> Void
    let onRequestNotificationAccess: () -> Void
    let onContinue: () -> Void
    
    var canContinue: Bool {
        mediaLibraryAuthorized
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Music Memory")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Track your music listening habits and see your personal Billboard chart")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "music.note",
                    title: "Media Library Access",
                    subtitle: "Required to track your music",
                    isGranted: mediaLibraryAuthorized,
                    action: onRequestMediaAccess
                )
                
                PermissionRow(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: "Get notified when songs change rank",
                    isGranted: notificationsAuthorized,
                    action: onRequestNotificationAccess
                )
            }
            .padding()
            
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!canContinue)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Enable", action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct LoadingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading your music library...")
                .font(.headline)
            
            Text("\(Int(progress * 100))%")
                .font(.title2)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(40)
    }
}

// MARK: - Previews

#Preview("Setup View - Initial") {
    SetupView(
        mediaLibraryAuthorized: false,
        notificationsAuthorized: false,
        onRequestMediaAccess: {},
        onRequestNotificationAccess: {},
        onContinue: {}
    )
}

#Preview("Setup View - Partially Authorized") {
    SetupView(
        mediaLibraryAuthorized: true,
        notificationsAuthorized: false,
        onRequestMediaAccess: {},
        onRequestNotificationAccess: {},
        onContinue: {}
    )
}

#Preview("Loading View") {
    LoadingView(progress: 0.65)
}
