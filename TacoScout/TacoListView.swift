import SwiftUI
import MapKit

// TacoListView is no longer used as a standalone modal sheet.
// The list content is now embedded in PersistentBottomSheet.
// The subviews below (TacoListItemView, PlaceholderImage, EmptyStateView)
// are shared between PersistentBottomSheet and TacoDetailView.

struct TacoListItemView: View {
    let taco: TacoLocation
    let userLocation: CLLocationCoordinate2D
    let isSelected: Bool
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    var distanceUnit: DistanceUnit = .miles
    var onPhotoTap: (() -> Void)? = nil

    var distance: Double {
        DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: distanceUnit)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Photo or Placeholder — tappable when photos exist
            if let firstPhoto = taco.photos.first {
                AsyncImage(url: URL(string: firstPhoto)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        PlaceholderImage(name: taco.name)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMedium))
                .clipped()
                .highPriorityGesture(
                    TapGesture().onEnded {
                        onPhotoTap?()
                    }
                )
            } else {
                PlaceholderImage(name: taco.name)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMedium))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(taco.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    if taco.isOpenNow {
                        OpenBadge()
                    }
                }
                
                HStack(spacing: 8) {
                    RatingBadge(rating: taco.rating)
                    
                    Text(taco.priceString)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tacoPriceTeal)
                    
                    Text(taco.cuisine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(taco.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Distance & Favorite
            VStack(alignment: .trailing, spacing: 8) {
                Text("\(String(format: "%.1f", distance)) \(distanceUnit.abbreviation)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Button(action: onFavoriteToggle) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .red : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.tacoOrange.opacity(0.2) : Color.clear)
    }
}

struct PlaceholderImage: View {
    var name: String? = nil

    private var initial: String {
        guard let name = name, let first = name.first else { return "🌮" }
        return String(first).uppercased()
    }

    private var accentColor: Color {
        guard let name = name else { return Color(.systemGray4) }
        let colors: [Color] = [.tacoOrange, .blue, .tacoGreen, .purple, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(
                Circle()
                    .fill(accentColor.opacity(0.8))
                    .padding(8)
                    .overlay(
                        Text(initial)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    )
            )
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if icon == "taco" {
                Text("🌮")
                    .font(.system(size: 60))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

/// Floating photo carousel overlay — appears when tapping a restaurant thumbnail.
struct FloatingPhotoCarousel: View {
    let taco: TacoLocation
    let onDismiss: () -> Void
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Carousel card
            VStack(spacing: 10) {
                // Restaurant name
                Text(taco.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)

                // Photo carousel
                TabView(selection: $selectedIndex) {
                    ForEach(Array(taco.photos.enumerated()), id: \.element) { index, url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundStyle(.gray)
                                    )
                            case .empty:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .overlay(ProgressView())
                            @unknown default:
                                Rectangle()
                                    .fill(Color(.systemGray5))
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.88 }
                .aspectRatio(88.0 / 66.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusLarge))

                // Photo count
                if taco.photos.count > 1 {
                    Text("\(selectedIndex + 1) of \(taco.photos.count)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

#Preview {
    TacoListItemView(
        taco: TacoLocation(
            id: "1",
            name: "El Farolito",
            latitude: 37.7749,
            longitude: -122.4194,
            cuisine: "Mexican Street Tacos",
            rating: 4.8,
            address: "Front St, San Francisco",
            priceLevel: 1,
            photos: [],
            reviews: [],
            hours: nil,
            phone: nil,
            website: nil
        ),
        userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        isSelected: false,
        isFavorite: false,
        onFavoriteToggle: {}
    )
}