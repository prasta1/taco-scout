import SwiftUI
import MapKit

struct TacoDetailView: View {
    let taco: TacoLocation
    let userLocation: CLLocationCoordinate2D
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedPhotoIndex = 0

    var distance: Double {
        DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: settingsManager.distanceUnit)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Drag Bar
                    Capsule()
                        .fill(Color(.systemGray3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Photo Gallery
                    if !taco.photos.isEmpty {
                        PhotoGallery(photos: taco.photos, selectedIndex: $selectedPhotoIndex)
                    } else {
                        // Placeholder header
                        ZStack {
                            LinearGradient(
                                colors: [.tacoOrange, .tacoYellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            VStack(spacing: 12) {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(String(taco.name.prefix(1)).uppercased())
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundColor(.white)
                                    )

                                Text(taco.name)
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .frame(height: 200)
                    }
                    
                    VStack(spacing: 20) {
                        // Header Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(taco.name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        
                                        if taco.isOpenNow {
                                            OpenBadge()
                                        }
                                    }
                                    
                                    Text(taco.cuisine)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Favorite Button
                                Button(action: {
                                    HapticManager.impact(.medium)
                                    onFavoriteToggle()
                                }) {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(isFavorite ? .red : .secondary)
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Stats Row
                            HStack(spacing: 20) {
                                StatBadge(icon: "star.fill", value: String(format: "%.1f", taco.rating), color: .orange)
                                StatBadge(icon: "dollarsign.circle.fill", value: taco.priceString, color: .tacoGreen)
                                StatBadge(icon: "location.fill", value: "\(String(format: "%.1f", distance)) \(settingsManager.distanceUnit.abbreviation)", color: .blue)
                            }
                            
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        
                        // Hours Section
                        if let hours = taco.hours {
                            InfoSection(title: "Hours") {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Circle()
                                            .fill(taco.isOpenNow ? Color.tacoGreen : Color.tacoRed)
                                            .frame(width: 8, height: 8)
                                        Text(taco.isOpenNow ? "Open Now" : "Closed")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(taco.isOpenNow ? .tacoGreen : .tacoRed)
                                    }
                                    
                                    Text("Today: \(hours.todayHours)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Address Section
                        InfoSection(title: "Location") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(taco.address)
                                    .font(.body)
                                
                                // Mini Map
                                Map(initialPosition: .region(MKCoordinateRegion(
                                    center: taco.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                ))) {
                                    Marker(taco.name, coordinate: taco.coordinate)
                                        .tint(.orange)
                                }
                                .frame(height: 150)
                                .cornerRadius(12)
                                .disabled(true)
                            }
                        }
                        
                        // Reviews Section
                        if !taco.reviews.isEmpty {
                            InfoSection(title: "Reviews") {
                                VStack(spacing: 12) {
                                    ForEach(taco.reviews.prefix(3)) { review in
                                        ReviewCard(review: review)
                                    }
                                }
                            }
                        }
                        
                        // Contact Section
                        if taco.phone != nil || taco.website != nil {
                            InfoSection(title: "Contact") {
                                VStack(spacing: 12) {
                                    if let phone = taco.phone {
                                        ContactButton(icon: "phone.fill", title: "Call", subtitle: phone) {
                                            if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                    }
                                    
                                    if let website = taco.website {
                                        ContactButton(icon: "globe", title: "Website", subtitle: website) {
                                            if let url = URL(string: website) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottom) {
                // Floating Action Buttons
                HStack(spacing: 12) {
                    Button(action: openInMaps) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button(action: openDelivery) {
                        Label("Order", systemImage: "bag.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.tacoGreen)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button(action: shareLocation) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .frame(width: 54, height: 54)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(14)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    func openInMaps() {
        HapticManager.impact(.medium)
        let encodedName = taco.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? taco.name
        if let url = URL(string: "maps://maps.apple.com/?q=\(encodedName)&ll=\(taco.latitude),\(taco.longitude)") {
            UIApplication.shared.open(url)
        }
    }

    func shareLocation() {
        HapticManager.impact(.light)
        let encodedName = taco.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var items: [Any] = ["\(taco.name) - \(taco.address)"]
        if let mapURL = URL(string: "https://maps.apple.com/?q=\(encodedName)&ll=\(taco.latitude),\(taco.longitude)") {
            items.append(mapURL)
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    func openDelivery() {
        HapticManager.impact(.medium)
        DeliveryLinkHelper.openBestOption(
            for: taco.name,
            latitude: taco.latitude,
            longitude: taco.longitude
        )
    }
}

// MARK: - Components

struct PhotoGallery: View {
    let photos: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .shimmer()
                    @unknown default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 250)
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

struct ReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(review.authorName.prefix(1)))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < Int(review.rating) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(review.relativeTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(review.text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ContactButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TacoDetailView(
        taco: TacoLocation(
            id: "1",
            name: "El Farolito",
            latitude: 37.7527,
            longitude: -122.4180,
            cuisine: "Mexican Street Tacos",
            rating: 4.8,
            address: "2779 Mission St, San Francisco",
            priceLevel: 1,
            photos: [],
            reviews: [
                Review(authorName: "John D.", rating: 5, text: "Best tacos in the city! The al pastor is incredible.", relativeTime: "2 weeks ago", profilePhotoUrl: nil)
            ],
            hours: nil,
            phone: "(415) 555-1234",
            website: "https://elfarolito.com"
        ),
        userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        isFavorite: false,
        onFavoriteToggle: {}
    )
}
