import SwiftUI
import MapKit
import os.log

private let logger = Logger(subsystem: "com.tacoscout.app", category: "ContentView")

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var favoritesManager = FavoritesManager()
    @State private var settingsManager = SettingsManager()
    @State private var tacos: [TacoLocation] = []
    @State private var selectedTaco: TacoLocation?
    @State private var showDetail = false
    @State private var sheetDetent: SheetDetent = .half
    @State private var filter = FilterState()
    @State private var luckyTaco: TacoLocation?
    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var showSearchOverlay = false
    @State private var mapZoomController = MapZoomController()
    @State private var refreshTask: Task<Void, Never>?
    @State private var loadingStatus: LoadingStatus = .locating
    @State private var lastSearchedLocation: CLLocationCoordinate2D?
    @State private var filteredTacos: [TacoLocation] = []

    /// Fixed location for App Store screenshot automation. Active only when the
    /// UI-test runner passes `-uiTestLocation "lat,lon"`; `nil` in normal use, so
    /// production behavior (real GPS + permission flow) is unaffected.
    private let debugLocationOverride: CLLocationCoordinate2D? = {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-uiTestLocation"), idx + 1 < args.count else { return nil }
        let parts = args[idx + 1].split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }()

    private func recomputeFilteredTacos() {
        guard let userLocation = effectiveUserLocation else {
            filteredTacos = []
            return
        }
        filteredTacos = TacoService.filtered(tacos: tacos, with: filter, from: userLocation)
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

    var body: some View {
        ZStack {
            if !tacos.isEmpty || debugLocationOverride != nil || loadingStatus == .done || loadingStatus == .noResults || loadingStatus == .locationDenied {
                portraitLayout
            } else if case .error = loadingStatus {
                LoadingOverlay(status: loadingStatus)
            } else if loadingStatus == .locating || loadingStatus == .searching {
                LoadingOverlay(status: loadingStatus)
            }

            topControls

            // Location denied inline banner
            if loadingStatus == .locationDenied {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Location access needed to find nearby tacos")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Button {
                            withAnimation(.easeInOut) {
                                loadingStatus = .noResults
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.tacoOrange)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(50)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: loadingStatus)
            }

            // Spotlight-style Search Overlay
            if showSearchOverlay {
                SearchOverlayView(
                    tacos: tacos,
                    userLocation: effectiveUserLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    distanceUnit: settingsManager.distanceUnit,
                    searchRadiusLabel: settingsManager.searchRadius.label(unit: settingsManager.distanceUnit),
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
        .environment(settingsManager)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            filter = settingsManager.defaultFilter()
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
        .onChange(of: tacos) { _, _ in recomputeFilteredTacos() }
        .onChange(of: filter) { _, _ in recomputeFilteredTacos() }
        .onChange(of: locationManager.userLocation?.latitude) { _, _ in recomputeFilteredTacos() }
        .onChange(of: locationManager.userLocation?.longitude) { _, _ in recomputeFilteredTacos() }
        .onOpenURL { url in
            if url.scheme == "tacoscout" && url.host == "lucky" {
                pickLuckyTaco()
            }
        }
    }

    // MARK: - Portrait Layout (Bottom Sheet)

    private var portraitLayout: some View {
        GeometryReader { proxy in
            let containerHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let safeAreaTop = proxy.safeAreaInsets.top
            let detentHeight = sheetDetent.height(in: containerHeight, safeAreaTop: safeAreaTop)

            ZStack {
                mapLayer(bottomInset: detentHeight)

                // Zoom Controls (Bottom Right) — track the sheet so they don't get obscured
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        zoomButtons
                            .padding(.trailing)
                            .padding(.bottom, detentHeight + 12)
                    }
                }
                .animation(.smooth, value: sheetDetent)

                // Bottom Sheet
                if let userLocation = effectiveUserLocation, !tacos.isEmpty {
                    bottomSheet(userLocation: userLocation)
                }
            }
        }
    }

    // MARK: - Shared Subviews

    private func mapLayer(bottomInset: CGFloat) -> some View {
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
            bottomInset: bottomInset
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
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.iconGrey)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Zoom in")

            Button(action: mapZoomController.zoomOut) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.iconGrey)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Zoom out")
        }
    }

    private func bottomSheet(userLocation: CLLocationCoordinate2D) -> some View {
        PersistentBottomSheet(
            tacos: filteredTacos,
            userLocation: userLocation,
            selectedTaco: $selectedTaco,
            favoritesManager: favoritesManager,
            currentDetent: $sheetDetent,
            filter: $filter,
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
            .sheet(item: $luckyTaco) { taco in
                LuckyPickView(
                    taco: taco,
                    userLocation: effectiveUserLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    onSelect: { picked in
                        luckyTaco = nil
                        selectedTaco = picked
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
                }
            }
            return
        }

        // React instantly when location becomes available — no polling
        let locationStartTime = Date()

        // Start the waiter FIRST (registers continuation), THEN request location.
        // This avoids a race where a cached location arrives before the waiter is registered.
        let locationTask = Task { @MainActor in
            await locationManager.nextLocation()
        }
        locationManager.requestLocation()

        // Watchdog: the loading overlay must NEVER hang indefinitely (App Store rejection 2.1a).
        // If location + search haven't resolved within the timeout, drop to a usable state
        // instead of spinning forever — covers denied/no-GPS-fix/stalled-API alike.
        let watchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            if loadingStatus == .locating || loadingStatus == .searching {
                logger.warning("⏱️ Loading watchdog fired — location/search did not resolve in time")
                // No location at all → show the "enable location" banner.
                // Have a location but search stalled → show the (usable) empty map.
                loadingStatus = locationManager.userLocation == nil ? .locationDenied : .noResults
            }
        }

        Task { @MainActor in
            let result = await locationTask.value
            switch result {
            case .coordinate(let location):
                let gpsElapsed = Date().timeIntervalSince(locationStartTime)
                logger.debug("⏱️ [TIMING] GPS location received in \(String(format: "%.2f", gpsElapsed))s — lat: \(location.latitude), lon: \(location.longitude)")
                lastSearchedLocation = location
                loadingStatus = .searching

                let apiStartTime = Date()
                let realTacos = await TacoService.searchNearbyTacos(location: location, radiusMeters: settingsManager.searchRadius.meters)
                let apiElapsed = Date().timeIntervalSince(apiStartTime)
                let totalElapsed = Date().timeIntervalSince(locationStartTime)
                logger.debug("⏱️ [TIMING] API returned \(realTacos.count) tacos in \(String(format: "%.2f", apiElapsed))s")
                logger.debug("⏱️ [TIMING] Total load time: \(String(format: "%.2f", totalElapsed))s (GPS: \(String(format: "%.2f", gpsElapsed))s + API: \(String(format: "%.2f", apiElapsed))s)")

                tacos = realTacos
                loadingStatus = realTacos.isEmpty ? .noResults : .done

            case .denied:
                loadingStatus = .locationDenied
            }
            // Loading reached a terminal state — stand down the watchdog.
            watchdog.cancel()
        }
    }

    /// Syncs client-side filters from settings defaults when the settings sheet is dismissed.
    /// Radius changes already trigger `refetchTacos()` via `.onChange`; `defaultFilter()`
    /// re-applies the same maxDistance that onChange set, so this stays in sync.
    func syncFiltersFromSettings() {
        filter = settingsManager.defaultFilter()
        SoundManager.enabled = settingsManager.soundsEnabled
    }

    func refetchTacos() {
        guard let location = effectiveUserLocation else { return }
        Task {
            let results = await TacoService.searchNearbyTacos(
                location: location,
                radiusMeters: settingsManager.searchRadius.meters
            )
            await MainActor.run {
                tacos = results
            }
        }
    }

    func refreshLocation() {
        HapticManager.impact(.medium)
        // Clear stale value so nextLocation() suspends until a fresh fix arrives.
        locationManager.userLocation = nil
        locationManager.requestLocation()

        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            let result = await locationManager.nextLocation()
            switch result {
            case .coordinate(let newLocation):
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
                    let results = await TacoService.searchNearbyTacos(
                        location: newLocation,
                        radiusMeters: settingsManager.searchRadius.meters
                    )
                    tacos = results
                }

            case .denied:
                loadingStatus = .locationDenied
            }
        }
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
                .accessibilityIdentifier("lucky-pick-button")
                .accessibilityLabel("Lucky pick")

            // Search bar — doubles as branding + taco count + search entry point
            Button(action: onSearchTap) {
                HStack(spacing: 8) {
                    Text("🌮")
                        .font(.system(size: 16))
                    Text("\(tacoCount) taco spot\(tacoCount == 1 ? "" : "s") nearby!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.tacoOrange, in: Capsule())
            }
            .buttonStyle(.plain)

            // Location Button
            ControlButton(icon: "location.fill", color: .tacoOrange, action: onLocationTap)
                .accessibilityLabel("Center on my location")

            // Settings Button
            ControlButton(icon: "gearshape.fill", color: .tacoOrange, action: onSettingsTap)
                .accessibilityIdentifier("filter-button")
                .accessibilityLabel("Settings")
                .overlay(alignment: .topTrailing) {
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.tacoRed, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
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
                .foregroundStyle(.white)
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
    case locationDenied
    case error(String)

    var message: String {
        switch self {
        case .locating: return "Locating you..."
        case .searching: return "Searching nearby..."
        case .done: return ""
        case .noResults: return "No taco spots found nearby"
        case .locationDenied: return "Location access denied. Enable in Settings to find tacos."
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

                Text(status.message)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: status.message)

                ProgressView()
                    .tint(.tacoOrange)
            }
            .frame(width: 220)
            .padding(32)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Layout.radiusLarge))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - UI Components

struct OpenBadge: View {
    var body: some View {
        Text("OPEN")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.tacoGreen, in: Capsule())
    }
}

struct RatingBadge: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct PhotoPreviewRow: View {
    let photos: [String]
    
    var body: some View {
        ScrollView(.horizontal) {
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
                                        .foregroundStyle(.gray)
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
                    .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMedium))
                    .clipped()
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Spotlight Search Overlay

struct SearchOverlayView: View {
    let tacos: [TacoLocation]
    let userLocation: CLLocationCoordinate2D
    let distanceUnit: DistanceUnit
    let searchRadiusLabel: String
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
                        .foregroundStyle(.secondary)

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
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }

                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.tacoOrange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusLarge))
                .padding(.horizontal, Layout.paddingContent)
                .padding(.top, Layout.topControlsHeight)

                // Results
                if searchText.isEmpty {
                    // Prompt
                    VStack(spacing: 8) {
                        Text("🌮")
                            .font(.system(size: 40))
                        Text("Search by name or neighborhood")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Searches all spots within your \(searchRadiusLabel) search radius, ignoring active filters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
                                .accessibilityAddTraits(.isButton)
                                .onTapGesture { onSelect(taco) }

                                if taco.id != results.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Layout.radiusLarge))
                        .padding(.horizontal, Layout.paddingContent)
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .foregroundStyle(Color.tacoPriceTeal)
                        .fontWeight(.semibold)
                    Text(taco.cuisine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text("\(String(format: "%.1f", distance)) \(distanceUnit.abbreviation)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.paddingContent)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
}
