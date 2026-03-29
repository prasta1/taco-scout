import SwiftUI
import MapKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.tacoscout.app", category: "ContentView")

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var settingsManager = SettingsManager()
    @ObservedObject private var adManager = AdManager.shared
    @State private var tacos: [TacoLocation] = []
    @State private var selectedTaco: TacoLocation?
    @State private var showDetail = false
    @State private var showLuckyPick = false
    @State private var triggerSearchFocus = false
    @State private var sheetDetent: SheetDetent = .half
    @State private var filter = FilterState()
    @State private var luckyTaco: TacoLocation?
    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var showSearchOverlay = false
    @State private var mapZoomController = MapZoomController()
    @State private var cancellables = Set<AnyCancellable>()
    @State private var loadingStatus: LoadingStatus = .locating
    @State private var lastSearchedLocation: CLLocationCoordinate2D?
    @Environment(\.verticalSizeClass) var verticalSizeClass

    private let debugLocationOverride: CLLocationCoordinate2D? = nil

    var filteredTacos: [TacoLocation] {
        guard let userLocation = effectiveUserLocation else { return [] }
        return TacoService.filtered(tacos: tacos, with: filter, from: userLocation)
    }
    
    var activeFilterCount: Int {
        var count = 0
        if filter.minRating > 0 { count += 1 }
        if filter.priceFilter != .any { count += 1 }
        if filter.openNowOnly { count += 1 }
        if filter.maxDistance != Double(settingsManager.searchRadius.rawValue) { count += 1 }
        return count
    }

    var effectiveUserLocation: CLLocationCoordinate2D? {
        debugLocationOverride ?? locationManager.userLocation
    }

    private var isLandscape: Bool {
        // iPhone landscape: verticalSizeClass == .compact
        // iPad landscape: both size classes stay .regular, so check device orientation
        if verticalSizeClass == .compact { return true }
        if UIDevice.current.userInterfaceIdiom == .pad {
            return UIDevice.current.orientation.isLandscape
        }
        return false
    }

    private var sidePanelWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 420 : 320
    }

    var body: some View {
        ZStack {
            if !tacos.isEmpty || debugLocationOverride != nil || loadingStatus == .done || loadingStatus == .noResults {
                if isLandscape {
                    landscapeLayout
                } else {
                    portraitLayout
                }
            } else if case .error = loadingStatus {
                LoadingOverlay(status: loadingStatus)
            } else if loadingStatus == .locating || loadingStatus == .searching {
                LoadingOverlay(status: loadingStatus)
            }

            // Top Controls — only in portrait (landscape puts them inside the map area)
            if !isLandscape {
                topControls
            }

            // Spotlight-style Search Overlay
            if showSearchOverlay {
                SearchOverlayView(
                    tacos: filteredTacos,
                    userLocation: effectiveUserLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    distanceUnit: settingsManager.distanceUnit,
                    onSelect: { taco in
                        showSearchOverlay = false
                        HapticManager.selection()
                        selectedTaco = taco
                        mapZoomController.centerOnCoordinate(taco.coordinate)
                    },
                    onDismiss: {
                        showSearchOverlay = false
                    }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSearchOverlay)
        .environmentObject(settingsManager)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            filter.sortBy = settingsManager.defaultSortOrder
            filter.maxDistance = Double(settingsManager.searchRadius.rawValue)
            filter.openNowOnly = settingsManager.defaultOpenNowOnly
            filter.minRating = settingsManager.defaultMinRating
            filter.priceFilter = settingsManager.defaultPriceFilter
            SoundManager.enabled = settingsManager.soundsEnabled
            checkOnboarding()
            locationManager.requestLocation()
            loadTacosFromLocation()
        }
        .onChange(of: settingsManager.soundsEnabled) { _, newValue in
            SoundManager.enabled = newValue
        }
        .onChange(of: settingsManager.searchRadius) { oldValue, newValue in
            guard oldValue != newValue else { return }
            filter.maxDistance = Double(newValue.rawValue)
            refetchTacos()
        }
        .onOpenURL { url in
            if url.scheme == "tacoscout" && url.host == "lucky" {
                pickLuckyTaco()
            }
        }
    }

    // MARK: - Portrait Layout (Bottom Sheet)

    private var portraitLayout: some View {
        ZStack {
            mapLayer(bottomInset: sheetDetent.height, leadingInset: 0)

            // Zoom Controls (Bottom Right, above sheet)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    zoomButtons
                        .padding(.trailing)
                        .padding(.bottom, 270)
                }
            }

            // Bottom Sheet
            if let userLocation = effectiveUserLocation, !tacos.isEmpty {
                bottomSheet(userLocation: userLocation)
            }
        }
    }

    // MARK: - Landscape Layout (Side Panel)

    private var landscapeLayout: some View {
        ZStack(alignment: .leading) {
            // Map fills entire space behind the floating panel
            ZStack {
                mapLayer(bottomInset: 0, leadingInset: sidePanelWidth + 24)

                // Top Controls — offset to clear the floating panel
                topControls
                    .padding(.leading, sidePanelWidth + 24)

                // Zoom Controls (Bottom Right)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        zoomButtons
                            .padding(.trailing)
                            .padding(.bottom, 16)
                    }
                }
            }

            // Floating side panel on left
            if let userLocation = effectiveUserLocation, !tacos.isEmpty {
                bottomSheet(userLocation: userLocation)
            }
        }
    }

    // MARK: - Shared Subviews

    private func mapLayer(bottomInset: CGFloat, leadingInset: CGFloat) -> some View {
        MapView(
            userLocation: effectiveUserLocation,
            tacos: filteredTacos,
            selectedTaco: $selectedTaco,
            onTacoSelect: { taco in
                HapticManager.selection()
                withAnimation(.bouncy) {
                    selectedTaco = taco
                }
            },
            zoomController: mapZoomController,
            bottomInset: bottomInset,
            leadingInset: leadingInset
        )
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings, onDismiss: syncFiltersFromSettings) {
            SettingsView(settingsManager: settingsManager, showOnboarding: $showOnboarding)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var zoomButtons: some View {
        VStack(spacing: 8) {
            Button(action: mapZoomController.zoomIn) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.iconGrey)
                    .clipShape(Circle())
            }

            Button(action: mapZoomController.zoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.iconGrey)
                    .clipShape(Circle())
            }
        }
    }

    private func bottomSheet(userLocation: CLLocationCoordinate2D) -> some View {
        PersistentBottomSheet(
            tacos: filteredTacos,
            userLocation: userLocation,
            selectedTaco: $selectedTaco,
            favoritesManager: favoritesManager,
            adManager: adManager,
            currentDetent: $sheetDetent,
            filter: $filter,
            triggerSearchFocus: $triggerSearchFocus,
            onDetailsTap: {
                HapticManager.impact(.medium)
                showDetail = true
            },
            onMapCenter: { coordinate in
                mapZoomController.centerOnCoordinate(coordinate)
            },
            onRefresh: {
                let results = await TacoService.searchNearbyTacos(
                    location: userLocation,
                    radiusMeters: settingsManager.searchRadius.meters
                )
                await MainActor.run { tacos = results }
            }
        )
        .sheet(isPresented: $showDetail) {
            if let taco = selectedTaco {
                TacoDetailView(
                    taco: taco,
                    userLocation: effectiveUserLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    isFavorite: favoritesManager.isFavorite(taco),
                    onFavoriteToggle: { favoritesManager.toggle(taco) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var topControls: some View {
        VStack(spacing: 0) {
            TopControlsBar(
                tacoCount: filteredTacos.count,
                activeFilterCount: activeFilterCount,
                onSearchTap: {
                    HapticManager.impact(.light)
                    showSearchOverlay = true
                },
                onLuckyTap: pickLuckyTaco,
                onLocationTap: refreshLocation,
                onSettingsTap: {
                    HapticManager.impact(.light)
                    showSettings.toggle()
                }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .sheet(isPresented: $showLuckyPick) {
                LuckyPickView(
                    taco: $luckyTaco,
                    userLocation: effectiveUserLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    onSelect: { taco in
                        showLuckyPick = false
                        selectedTaco = taco
                    },
                    onReroll: pickLuckyTaco
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }

            Spacer()
        }
    }

    // MARK: - Data Loading

    func loadTacosFromLocation() {
        loadingStatus = .locating

        // If using debug location override, fetch tacos immediately
        if let debugLocation = debugLocationOverride {
            logger.debug("Using override location \(debugLocation.latitude), \(debugLocation.longitude)")
            loadingStatus = .searching
            lastSearchedLocation = debugLocation
            Task {
                let osmTacos = await TacoService.searchNearbyTacos(location: debugLocation, radiusMeters: settingsManager.searchRadius.meters)
                await MainActor.run {
                    tacos = osmTacos
                    loadingStatus = osmTacos.isEmpty ? .noResults : .done
                    if !osmTacos.isEmpty { adManager.loadAds(count: 3) }
                }
            }
            return
        }

        // React instantly when location becomes available — no polling
        let locationStartTime = Date()
        locationManager.$userLocation
            .compactMap { $0 }
            .first()
            .sink { location in
                let gpsElapsed = Date().timeIntervalSince(locationStartTime)
                logger.debug("⏱️ [TIMING] GPS location received in \(String(format: "%.2f", gpsElapsed))s — lat: \(location.latitude), lon: \(location.longitude)")
                self.lastSearchedLocation = location
                self.loadingStatus = .searching
                Task {
                    let apiStartTime = Date()
                    let realTacos = await TacoService.searchNearbyTacos(location: location, radiusMeters: self.settingsManager.searchRadius.meters)
                    let apiElapsed = Date().timeIntervalSince(apiStartTime)
                    let totalElapsed = Date().timeIntervalSince(locationStartTime)
                    logger.debug("⏱️ [TIMING] API returned \(realTacos.count) tacos in \(String(format: "%.2f", apiElapsed))s")
                    logger.debug("⏱️ [TIMING] Total load time: \(String(format: "%.2f", totalElapsed))s (GPS: \(String(format: "%.2f", gpsElapsed))s + API: \(String(format: "%.2f", apiElapsed))s)")
                    await MainActor.run {
                        tacos = realTacos
                        self.loadingStatus = realTacos.isEmpty ? .noResults : .done
                        if !realTacos.isEmpty { self.adManager.loadAds(count: 3) }
                    }
                }
            }
            .store(in: &cancellables)

        // Note: No fallback — loading overlay stays until GPS + Google Places resolve
    }

    /// Syncs client-side filters from settings defaults when the settings sheet is dismissed.
    /// Radius changes already trigger `refetchTacos()` via `.onChange`, so this only handles
    /// the non-API filters (sort, rating, price, open now).
    func syncFiltersFromSettings() {
        filter.sortBy = settingsManager.defaultSortOrder
        filter.openNowOnly = settingsManager.defaultOpenNowOnly
        filter.minRating = settingsManager.defaultMinRating
        filter.priceFilter = settingsManager.defaultPriceFilter
        SoundManager.enabled = settingsManager.soundsEnabled
    }

    func refetchTacos() {
        guard let location = effectiveUserLocation else { return }
        Task {
            let results = await TacoService.searchNearbyTacos(
                location: location,
                radiusMeters: settingsManager.searchRadius.meters
            )
            await MainActor.run { tacos = results }
        }
    }

    func refreshLocation() {
        HapticManager.impact(.medium)
        locationManager.requestLocation()

        // Wait for new location, then center map and refetch if we've moved significantly
        locationManager.$userLocation
            .compactMap { $0 }
            .first()
            .sink { newLocation in
                mapZoomController.centerOnUserLocation(newLocation)

                // Refetch if we've moved more than ~500m from last search, or never searched
                let shouldRefetch: Bool
                if let lastSearch = lastSearchedLocation {
                    let distance = CLLocation(latitude: lastSearch.latitude, longitude: lastSearch.longitude)
                        .distance(from: CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude))
                    shouldRefetch = distance > 500
                } else {
                    shouldRefetch = true
                }

                if shouldRefetch {
                    lastSearchedLocation = newLocation
                    Task {
                        let results = await TacoService.searchNearbyTacos(
                            location: newLocation,
                            radiusMeters: settingsManager.searchRadius.meters
                        )
                        await MainActor.run { tacos = results }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func pickLuckyTaco() {
        logger.debug("🎲 pickLuckyTaco called — filteredTacos: \(filteredTacos.count), tacos: \(tacos.count)")
        guard let pick = TacoService.randomPick(from: filteredTacos) else {
            logger.debug("🎲 randomPick returned nil")
            return
        }
        logger.debug("🎲 picked: \(pick.name)")
        HapticManager.notification(.success)
        SoundManager.playLuckySound()
        luckyTaco = pick
        showLuckyPick = true
    }
    
    func checkOnboarding() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        if !hasSeenOnboarding {
            showOnboarding = true
        }
    }
}

// MARK: - Top Controls Bar

struct TopControlsBar: View {
    let tacoCount: Int
    let activeFilterCount: Int
    let onSearchTap: () -> Void
    let onLuckyTap: () -> Void
    let onLocationTap: () -> Void
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Lucky Button
            ControlButton(icon: "dice.fill", color: .tacoOrange, action: onLuckyTap)

            // Search bar — doubles as branding + taco count + search entry point
            Button(action: onSearchTap) {
                HStack(spacing: 8) {
                    Text("🌮")
                        .font(.system(size: 16))
                    Text("\(tacoCount) taco spot\(tacoCount == 1 ? "" : "s") nearby!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.tacoOrange, in: Capsule())
            }
            .buttonStyle(.plain)

            // Location Button
            ControlButton(icon: "location.fill", color: .tacoOrange, action: onLocationTap)

            // Settings Button
            ControlButton(icon: "gearshape.fill", color: .tacoOrange, action: onSettingsTap)
        }
        .frame(maxWidth: 500)
    }
}

struct ControlButton: View {
    let icon: String
    var color: Color = .tacoOrange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(12)
                .background(color)
                .clipShape(Circle())
        }
    }
}

// MARK: - Loading Status

enum LoadingStatus: Equatable {
    case locating
    case searching
    case done
    case noResults
    case error(String)

    var message: String {
        switch self {
        case .locating: return "Locating you..."
        case .searching: return "Searching nearby..."
        case .done: return ""
        case .noResults: return "No taco spots found nearby"
        case .error(let msg): return msg
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var status: LoadingStatus
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🌮")
                    .font(.system(size: 60))
                    .rotationEffect(.degrees(isAnimating ? 10 : -10))
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isAnimating)

                Text(status.message)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: status.message)

                ProgressView()
                    .tint(.tacoOrange)
            }
            .padding(32)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - UI Components

struct OpenBadge: View {
    var body: some View {
        Text("OPEN")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.tacoGreen)
            .cornerRadius(4)
    }
}

struct RatingBadge: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundColor(.orange)
            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct PhotoPreviewRow: View {
    let photos: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos.prefix(4), id: \.self) { url in
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
                    .frame(width: 70, height: 70)
                    .cornerRadius(8)
                    .clipped()
                }
            }
        }
    }
}

// MARK: - Spotlight Search Overlay

struct SearchOverlayView: View {
    let tacos: [TacoLocation]
    let userLocation: CLLocationCoordinate2D
    let distanceUnit: DistanceUnit
    let onSelect: (TacoLocation) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    var results: [TacoLocation] {
        guard !searchText.isEmpty else { return [] }
        return tacos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.cuisine.localizedCaseInsensitiveContains(searchText) ||
            $0.address.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            // Blurred background — tap to dismiss
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Find your next taco fix...", text: $searchText)
                        .font(.system(size: 18))
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .submitLabel(.search)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.tacoOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
                .padding(.top, 60)

                // Results
                if searchText.isEmpty {
                    // Prompt
                    VStack(spacing: 8) {
                        Text("🌮")
                            .font(.system(size: 40))
                        Text("Search by name or neighborhood")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { taco in
                                SearchResultRow(
                                    taco: taco,
                                    userLocation: userLocation,
                                    distanceUnit: distanceUnit,
                                    searchText: searchText
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect(taco) }

                                if taco.id != results.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            isFocused = true
        }
    }
}

/// A single row in the search overlay results list.
struct SearchResultRow: View {
    let taco: TacoLocation
    let userLocation: CLLocationCoordinate2D
    let distanceUnit: DistanceUnit
    let searchText: String

    var distance: Double {
        DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: distanceUnit)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail
            Group {
                if let firstPhoto = taco.photos.first {
                    AsyncImage(url: URL(string: firstPhoto)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            PlaceholderImage(name: taco.name)
                        }
                    }
                } else {
                    PlaceholderImage(name: taco.name)
                }
            }
            .frame(width: 44, height: 44)
            .cornerRadius(8)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(taco.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if taco.isOpenNow {
                        OpenBadge()
                    }
                }

                HStack(spacing: 6) {
                    RatingBadge(rating: taco.rating)
                    Text(taco.priceString)
                        .font(.caption2)
                        .foregroundColor(.tacoGreen)
                        .fontWeight(.semibold)
                    Text(taco.cuisine)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text("\(String(format: "%.1f", distance)) \(distanceUnit.abbreviation)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
}
