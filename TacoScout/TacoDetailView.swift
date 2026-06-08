import SwiftUI
import MapKit

struct TacoDetailView: View {
    let taco: TacoLocation
    let userLocation: CLLocationCoordinate2D
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(SettingsManager.self) private var settingsManager
    @State private var selectedPhotoIndex = 0
    @State private var showAllHours = false
    @State private var loadedReviews: [Review] = []
    @State private var reviewsLoading = false
    @State private var showOrderSheet = false

    var distance: Double {
        DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: settingsManager.distanceUnit)
    }

    /// Delivery apps currently installed on this device.
    var availableOrderingApps: [DeliveryLinkHelper.DeliveryOption] {
        DeliveryLinkHelper.options(for: taco.name, latitude: taco.latitude, longitude: taco.longitude)
            .filter { $0.isAppInstalled }
    }

    /// Label and icon for the Order button based on the tier chain.
    /// Returns nil when no ordering is possible at all (no apps, no website, no phone).
    var orderButtonConfig: (label: String, icon: String)? {
        let apps = availableOrderingApps
        if apps.count == 1 { return ("Order on \(apps[0].name)", apps[0].icon) }
        if apps.count > 1  { return ("Order", "bag.fill") }
        if taco.website != nil { return ("Order Online", "globe") }
        if taco.phone != nil   { return ("Call to Order", "phone.fill") }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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
                                StatBadge(icon: "dollarsign.circle.fill", value: taco.priceString, color: .tacoPriceTeal)
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
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showAllHours.toggle()
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Text(showAllHours ? "Less" : "All hours")
                                                    .font(.caption)
                                                Image(systemName: showAllHours ? "chevron.up" : "chevron.down")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                    }

                                    if showAllHours {
                                        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(Array(hours.weekdayText.enumerated()), id: \.offset) { index, dayText in
                                                Text(dayText)
                                                    .font(.subheadline)
                                                    .foregroundColor(index == todayIndex ? .primary : .secondary)
                                                    .fontWeight(index == todayIndex ? .semibold : .regular)
                                            }
                                        }
                                    } else {
                                        Text("Today: \(hours.todayHours)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
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
                        if reviewsLoading {
                            InfoSection(title: "Reviews") {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                    Text("Loading reviews…")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else if !loadedReviews.isEmpty {
                            InfoSection(title: "Reviews") {
                                VStack(spacing: 12) {
                                    ForEach(loadedReviews.prefix(5)) { review in
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
                        
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            .task {
                reviewsLoading = true
                loadedReviews = await TacoService.fetchReviews(placeId: taco.id)
                reviewsLoading = false
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(action: openInMaps) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(Layout.radiusLarge)
                    }

                    if let config = orderButtonConfig {
                        Button(action: openDelivery) {
                            Label(config.label, systemImage: config.icon)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.tacoGreen)
                                .foregroundColor(.white)
                                .cornerRadius(Layout.radiusLarge)
                        }
                        .confirmationDialog(
                            "Order from \(taco.name)",
                            isPresented: $showOrderSheet,
                            titleVisibility: .visible
                        ) {
                            ForEach(availableOrderingApps, id: \.name) { option in
                                Button(option.name) {
                                    UIApplication.shared.open(option.bestURL)
                                }
                            }
                        }
                    } else {
                        Text("Ordering not available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(Layout.radiusLarge)
                    }

                    Button(action: shareLocation) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .frame(width: 54, height: 54)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(Layout.radiusLarge)
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
        let apps = availableOrderingApps

        // Tier 2: 2+ apps installed — present a choice
        if apps.count > 1 {
            showOrderSheet = true
            return
        }

        // Tier 2: exactly 1 app — open directly
        if let single = apps.first {
            UIApplication.shared.open(single.bestURL)
            return
        }

        // Tier 3: no apps, but restaurant has a website
        if let website = taco.website, let url = URL(string: website) {
            UIApplication.shared.open(url)
            return
        }

        // Tier 4: fall back to phone dialer
        if let phone = taco.phone,
           let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
            UIApplication.shared.open(url)
        }
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
