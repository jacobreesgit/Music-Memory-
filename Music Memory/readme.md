# Music Memory - Personal Music Analytics App

## Overview
Music Memory is an iOS app that tracks your music listening habits and generates a dynamic, Billboard-style chart of your most played songs based on your device's local music library.

## Features
- 📊 **Billboard-Style Chart**: Dynamic ranking of your most played songs
- 🕰️ **Time-Based Filters**: View charts for all-time, this week, this month, or this year
- 📈 **Rank Tracking**: See how songs move up and down the charts with visual indicators
- 🔔 **Push Notifications**: Get notified when songs change rank
- 🎵 **Background Tracking**: Monitors playback even when the app is in the background

## Architecture

### Core Components

#### SwiftData Models
- **TrackedSong**: Stores song metadata, play counts, and ranking information
- **PlayEvent**: Individual play events with timestamps for time-based filtering

#### Key Services
- **MediaLibraryManager**: Handles initial library import and MediaPlayer framework interaction
- **NowPlayingTracker**: Monitors playback changes and logs play events
- **NotificationManager**: Manages local push notifications for rank changes

#### Views
- **MainView**: App entry point, handles permissions and setup flow
- **ChartView**: Main chart display with filtering options
- **SetupView**: Initial permissions and onboarding

### Technical Details

#### Permissions Required
1. **Media Library Access** (`NSAppleMusicUsageDescription`)
2. **Push Notifications** (Local notifications only)

#### Background Modes
- **Audio** (`UIBackgroundModes: audio`) - For tracking playback changes

#### Entitlements
- `com.apple.security.media-library.read` - Required for MediaPlayer framework

## Setup Instructions

1. **Create a new iOS app project** in Xcode
2. **Set minimum deployment target** to iOS 18.0
3. **Add all source files** to your project
4. **Configure Info.plist** with the provided configuration
5. **Add entitlements file** to your project and configure in project settings
6. **Enable capabilities** in Xcode:
   - Background Modes → Audio
   - Push Notifications

## How It Works

### Initial Setup
1. App requests media library access
2. Loads all songs from the device's music library
3. Stores baseline play counts from MediaPlayer
4. Creates TrackedSong records in SwiftData

### Play Tracking
1. Monitors `MPMusicPlayerController.systemMusicPlayer`
2. Detects when `nowPlayingItem` changes
3. Checks if play count increased
4. Logs PlayEvent with timestamp
5. Updates rankings and sends notifications

### Ranking System
- Songs are ranked by total plays (baseline + local)
- Time filters use PlayEvent timestamps
- Rank changes are tracked and displayed with indicators
- Push notifications sent when songs move ranks

## Important Notes

- **MediaPlayer is only used once** during initial setup to get baseline counts
- All subsequent tracking is handled through SwiftData
- The app must be running (foreground or background) to track plays
- Background audio mode allows tracking while music plays
- Play detection relies on MediaPlayer's play count changes

## File Structure
```
MusicMemoryApp.swift         - Main app entry point
Models/
  TrackedSong.swift         - Song data model
  PlayEvent.swift           - Play event model
Services/
  MediaLibraryManager.swift - Library import service
  NowPlayingTracker.swift   - Playback monitoring
  NotificationManager.swift - Push notification handler
ViewModels/
  ChartViewModel.swift      - Chart data management
Views/
  MainView.swift           - App root view
  ChartView.swift          - Billboard chart display
  SetupView.swift          - Permissions setup view
Configuration/
  Info.plist               - App configuration
  MusicMemory.entitlements - App entitlements
```

## Future Enhancements
- Export chart data
- Social sharing features
- Custom time ranges
- Detailed play statistics
- Widget support
- Apple Music integration
