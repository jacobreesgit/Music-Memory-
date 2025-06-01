import SwiftUI
import SwiftData

struct ChartView: View {
    @StateObject private var viewModel: ChartViewModel
    @Environment(\.modelContext) private var modelContext
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: ChartViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter buttons
                FilterBar(selectedFilter: $viewModel.selectedFilter) { filter in
                    viewModel.changeFilter(to: filter)
                }
                
                if viewModel.isLoading {
                    ProgressView("Loading chart...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.songs.isEmpty {
                    EmptyChartView()
                } else {
                    // ✅ Optimized list rendering
                    OptimizedChartList(songs: viewModel.songs, filter: viewModel.selectedFilter)
                }
            }
            .navigationTitle("Music Memory")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadSongs()
            }
        }
    }
}

// ✅ Separate optimized list component
struct OptimizedChartList: View {
    let songs: [TrackedSong]
    let filter: TimeFilter
    
    var body: some View {
        ScrollView {
            // Use LazyVStack with reduced spacing for better performance
            LazyVStack(spacing: 1) {
                ForEach(Array(songs.enumerated()), id: \.element.persistentID) { index, song in
                    ChartRowView(
                        rank: index + 1,
                        song: song,
                        filter: filter
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                    if index < songs.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        // ✅ Add content shape for better scrolling performance
        .contentShape(Rectangle())
    }
}

struct FilterBar: View {
    @Binding var selectedFilter: TimeFilter
    let onFilterChange: (TimeFilter) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        onFilterChange(filter)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(UIColor.secondarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

struct ChartRowView: View {
    let rank: Int
    let song: TrackedSong
    let filter: TimeFilter
    
    // ✅ Cache the play count calculation
    private var playCount: Int {
        song.getPlayCount(for: filter)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            VStack(spacing: 4) {
                Text("#\(rank)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                
                RankChangeIndicator(change: song.rankChange)
            }
            .frame(width: 60)
            
            // Album artwork - using simple artwork view
            AlbumArtworkView(artworkData: song.artworkData)
                .frame(width: 60, height: 60)
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let albumTitle = song.albumTitle {
                    Text(albumTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Play count
            VStack {
                Text("\(playCount)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                
                Text("plays")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

struct RankChangeIndicator: View {
    let change: RankChange
    
    var body: some View {
        Text(change.symbol)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(change.color)
    }
}

struct AlbumArtworkView: View {
    let artworkData: Data?
    
    var body: some View {
        if let artworkData = artworkData,
           let uiImage = UIImage(data: artworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemFill))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.secondary)
                )
        }
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No songs tracked yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Play some music to see your chart!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
