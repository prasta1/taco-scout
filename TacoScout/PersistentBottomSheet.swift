import SwiftUI
import MapKit

// MARK: - Sheet Detent

enum SheetDetent: CaseIterable {
    case peek
    case half
    case full

    var height: CGFloat {
        switch self {
        case .peek: return 260
        case .half: return UIScreen.main.bounds.height * 0.45
        case .full: return UIScreen.main.bounds.height
        }
    }

    static func nearest(to height: CGFloat, velocity: CGFloat) -> SheetDetent {
        let cases = SheetDetent.allCases
        let velocityThreshold: CGFloat = 300

        if abs(velocity) > velocityThreshold {
            let currentIndex = cases.firstIndex(where: {
                abs($0.height - height) < UIScreen.main.bounds.height * 0.2
            }) ?? 0
            if velocity < 0 {
                return cases[min(currentIndex + 1, cases.count - 1)]
            } else {
                return cases[max(currentIndex - 1, 0)]
            }
        }

        return cases.min(by: {
            abs($0.height - height) < abs($1.height - height)
        }) ?? .peek
    }
}

// MARK: - UIKit Bottom Sheet Container

/// A UIKit container that hosts SwiftUI content and handles pan gestures
/// entirely at the UIKit level. During a drag, only the UIView's frame.origin.y
/// changes — no SwiftUI state updates, no body re-evaluation, no jitter.
struct BottomSheetContainer<Content: View>: UIViewControllerRepresentable {
    @Binding var currentDetent: SheetDetent
    let content: Content

    init(currentDetent: Binding<SheetDetent>, @ViewBuilder content: () -> Content) {
        self._currentDetent = currentDetent
        self.content = content()
    }

    func makeUIViewController(context: Context) -> BottomSheetHostController {
        let controller = BottomSheetHostController(
            rootContent: AnyView(content),
            detent: currentDetent,
            onDetentChange: { newDetent in
                currentDetent = newDetent
            }
        )
        return controller
    }

    func updateUIViewController(_ controller: BottomSheetHostController, context: Context) {
        controller.updateContent(AnyView(content))
        // Only animate to the new detent if SwiftUI changed it externally
        // (e.g. search button sets .full) and we're not mid-drag
        if !controller.isDragging && controller.currentDetent != currentDetent {
            controller.animateToDetent(currentDetent)
        }
    }
}

/// A UIView that passes through touches outside its subviews.
/// This ensures the area above the visible sheet doesn't eat map/button touches.
private class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        // If the touch would hit this view itself (not a subview), return nil to pass through
        return result == self ? nil : result
    }
}

/// UIViewController that hosts SwiftUI content and manages pan gesture for the sheet.
/// Non-generic to allow @objc UIGestureRecognizerDelegate conformance.
class BottomSheetHostController: UIViewController, UIGestureRecognizerDelegate {
    private var hostingController: UIHostingController<AnyView>
    private(set) var currentDetent: SheetDetent
    private var onDetentChange: (SheetDetent) -> Void
    private(set) var isDragging = false
    private var dragStartY: CGFloat = 0

    private let screenHeight = UIScreen.main.bounds.height

    /// The Y origin for a given detent (distance from top of screen)
    private func yOrigin(for detent: SheetDetent) -> CGFloat {
        screenHeight - detent.height
    }

    init(rootContent: AnyView, detent: SheetDetent, onDetentChange: @escaping (SheetDetent) -> Void) {
        self.currentDetent = detent
        self.onDetentChange = onDetentChange
        self.hostingController = UIHostingController(rootView: rootContent)
        self.hostingController.view.backgroundColor = .clear
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        // Use a pass-through view so touches above the sheet hit the map/controls
        self.view = PassthroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // Add hosting controller as child
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // Set up pan gesture on the hosting view
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        hostingController.view.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isDragging else { return }
        // Position the sheet at the current detent
        let y = yOrigin(for: currentDetent)
        hostingController.view.frame = CGRect(
            x: 0, y: y,
            width: view.bounds.width, height: screenHeight
        )
    }

    func updateContent(_ content: AnyView) {
        hostingController.rootView = content
    }

    func animateToDetent(_ detent: SheetDetent) {
        currentDetent = detent
        let targetY = yOrigin(for: detent)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.hostingController.view.frame.origin.y = targetY
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isDragging = true
            dragStartY = hostingController.view.frame.origin.y

        case .changed:
            let translation = gesture.translation(in: view).y
            var newY = dragStartY + translation
            // Clamp: don't allow dragging above full height
            let minY = yOrigin(for: .full)
            // Allow some rubber-band past peek but with resistance
            let maxY = yOrigin(for: .peek)
            if newY < minY {
                // Rubber band above full
                let overshoot = minY - newY
                newY = minY - overshoot * 0.3
            } else if newY > maxY {
                // Rubber band below peek
                let overshoot = newY - maxY
                newY = maxY + overshoot * 0.3
            }
            hostingController.view.frame.origin.y = newY

            // Lock any embedded scroll views to the top while dragging the sheet down
            if translation > 0 {
                lockScrollViewsToTop(in: hostingController.view)
            }

        case .ended, .cancelled:
            isDragging = false
            let velocity = gesture.velocity(in: view).y
            let currentY = hostingController.view.frame.origin.y
            let currentHeight = screenHeight - currentY
            let newDetent = SheetDetent.nearest(to: currentHeight, velocity: velocity)
            currentDetent = newDetent
            let targetY = yOrigin(for: newDetent)

            // Use spring animation with velocity
            let distance = targetY - currentY
            let springVelocity: CGFloat = distance != 0 ? velocity / distance : 0

            UIView.animate(
                withDuration: 0.45,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: abs(springVelocity),
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                self.hostingController.view.frame.origin.y = targetY
            } completion: { _ in
                self.onDetentChange(newDetent)
            }

        default:
            break
        }
    }

    /// Prevents scroll views from scrolling while the sheet itself is being dragged.
    private func lockScrollViewsToTop(in view: UIView) {
        if let scrollView = view as? UIScrollView, scrollView.contentOffset.y > 0 {
            scrollView.contentOffset = .zero
        }
        for subview in view.subviews {
            lockScrollViewsToTop(in: subview)
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        // Only handle vertical drags — let horizontal gestures pass through
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow simultaneous recognition with scroll views so downward
        // swipes on list content can collapse the sheet when scrolled to top
        if let scrollView = otherGestureRecognizer.view as? UIScrollView {
            return scrollView.contentOffset.y <= 0
        }
        return false
    }
}

// MARK: - Persistent Bottom Sheet

struct PersistentBottomSheet: View {
    let tacos: [TacoLocation]
    let userLocation: CLLocationCoordinate2D
    @Binding var selectedTaco: TacoLocation?
    @ObservedObject var favoritesManager: FavoritesManager
    @ObservedObject var adManager: AdManager
    @Binding var currentDetent: SheetDetent
    @Binding var filter: FilterState
    @Binding var triggerSearchFocus: Bool
    let onDetailsTap: () -> Void
    let onMapCenter: (CLLocationCoordinate2D) -> Void
    var onRefresh: (() async -> Void)? = nil
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var carouselTaco: TacoLocation?
    @FocusState private var isSearchFocused: Bool

    var filteredTacos: [TacoLocation] {
        var result = tacos

        if showFavoritesOnly {
            result = result.filter { favoritesManager.isFavorite($0) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.cuisine.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    /// Tacos to show in the list — excludes the selected taco since it's shown in the card above.
    var listTacos: [TacoLocation] {
        guard let selected = selectedTaco else { return filteredTacos }
        return filteredTacos.filter { $0.id != selected.id }
    }

    var hasActiveFilters: Bool {
        filter.minRating > 0 || filter.priceFilter != .any || filter.openNowOnly || filter.maxDistance != Double(settingsManager.searchRadius.rawValue) || showFavoritesOnly
    }

    private var isLandscape: Bool {
        if verticalSizeClass == .compact { return true }
        if UIDevice.current.userInterfaceIdiom == .pad {
            return UIDevice.current.orientation.isLandscape
        }
        return false
    }

    private var panelWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 420 : 320
    }

    var body: some View {
        Group {
            if isLandscape {
                landscapePanel
            } else {
                BottomSheetContainer(currentDetent: $currentDetent) {
                    sheetContent
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay {
            if let taco = carouselTaco {
                FloatingPhotoCarousel(taco: taco) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        carouselTaco = nil
                    }
                }
            }
        }
        .onChange(of: triggerSearchFocus) { _, newValue in
            if newValue {
                isSearchFocused = true
                triggerSearchFocus = false
            }
        }
    }

    // MARK: - Landscape Side Panel

    private var landscapePanel: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                // HEADER (no drag handle in landscape)
                SheetHeader(
                    tacoCount: filteredTacos.count,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // SELECTED TACO CARD
                if let taco = selectedTaco {
                    SelectedTacoSection(
                        taco: taco,
                        userLocation: userLocation,
                        isFavorite: favoritesManager.isFavorite(taco),
                        onFavoriteToggle: { favoritesManager.toggle(taco) },
                        onDetailsTap: onDetailsTap,
                        onDismiss: {
                            withAnimation(.smooth) {
                                selectedTaco = nil
                            }
                        },
                        distanceUnit: settingsManager.distanceUnit
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // FILTER CHIPS
                FilterChipsRow(
                    filter: $filter,
                    showFavoritesOnly: $showFavoritesOnly,
                    favoritesCount: tacos.filter { favoritesManager.isFavorite($0) }.count,
                    hasActiveFilters: hasActiveFilters
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 12)

                // LIST — always scrollable in landscape
                if listTacos.isEmpty && selectedTaco == nil {
                    EmptyStateView(
                        icon: showFavoritesOnly ? "heart.slash" : "taco",
                        title: showFavoritesOnly ? "No Favorites Yet" : "No Tacos Found",
                        subtitle: showFavoritesOnly ? "Tap the heart on any taco to save it" : "Try adjusting your filters"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(listTacos.enumerated()), id: \.element.id) { index, taco in
                                TacoListItemView(
                                    taco: taco,
                                    userLocation: userLocation,
                                    isSelected: false,
                                    isFavorite: favoritesManager.isFavorite(taco),
                                    onFavoriteToggle: { favoritesManager.toggle(taco) },
                                    distanceUnit: settingsManager.distanceUnit,
                                    onPhotoTap: taco.photos.isEmpty ? nil : {
                                        HapticManager.selection()
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            carouselTaco = taco
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticManager.selection()
                                    selectedTaco = taco
                                    onMapCenter(taco.coordinate)
                                }

                                if taco.id != listTacos.last?.id {
                                    Divider()
                                        .padding(.leading, 88)
                                        .padding(.trailing, 16)
                                }

                                // Insert native ad after every 5th item
                                if (index + 1) % 5 == 0, let ad = adManager.loadedAds[safe: (index + 1) / 5 - 1] {
                                    AdNativeView(nativeAd: ad)
                                        .frame(height: 120)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    .refreshable {
                        HapticManager.impact(.medium)
                        await onRefresh?()
                    }
                }
            }
        }
        .frame(width: panelWidth)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 0)
        .padding(12)
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // DRAG HANDLE + HEADER
            VStack(spacing: 10) {
                HandleBar()
                    .padding(.top, 10)

                SheetHeader(
                    tacoCount: filteredTacos.count,
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // SELECTED TACO CARD
            if let taco = selectedTaco {
                SelectedTacoSection(
                    taco: taco,
                    userLocation: userLocation,
                    isFavorite: favoritesManager.isFavorite(taco),
                    onFavoriteToggle: { favoritesManager.toggle(taco) },
                    onDetailsTap: onDetailsTap,
                    onDismiss: {
                        withAnimation(.smooth) {
                            selectedTaco = nil
                        }
                    },
                    distanceUnit: settingsManager.distanceUnit
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // FILTER CHIPS
            FilterChipsRow(
                filter: $filter,
                showFavoritesOnly: $showFavoritesOnly,
                favoritesCount: tacos.filter { favoritesManager.isFavorite($0) }.count,
                hasActiveFilters: hasActiveFilters
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // LIST
            if listTacos.isEmpty && selectedTaco == nil {
                EmptyStateView(
                    icon: showFavoritesOnly ? "heart.slash" : "taco",
                    title: showFavoritesOnly ? "No Favorites Yet" : "No Tacos Found",
                    subtitle: showFavoritesOnly ? "Tap the heart on any taco to save it" : "Try adjusting your filters"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(listTacos.enumerated()), id: \.element.id) { index, taco in
                            TacoListItemView(
                                taco: taco,
                                userLocation: userLocation,
                                isSelected: false,
                                isFavorite: favoritesManager.isFavorite(taco),
                                onFavoriteToggle: { favoritesManager.toggle(taco) },
                                distanceUnit: settingsManager.distanceUnit,
                                onPhotoTap: taco.photos.isEmpty ? nil : {
                                    HapticManager.selection()
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        carouselTaco = taco
                                    }
                                }
                            )
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticManager.selection()
                                selectedTaco = taco
                                onMapCenter(taco.coordinate)
                                if currentDetent == .peek {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        currentDetent = .half
                                    }
                                }
                            }

                            if taco.id != listTacos.last?.id {
                                Divider()
                                    .padding(.leading, 92)
                            }

                            // Insert native ad after every 5th item
                            if (index + 1) % 5 == 0, let ad = adManager.loadedAds[safe: (index + 1) / 5 - 1] {
                                AdNativeView(nativeAd: ad)
                                    .frame(height: 120)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .refreshable {
                    HapticManager.impact(.medium)
                    await onRefresh?()
                }
                .scrollDisabled(currentDetent != .full)
            }

            Spacer(minLength: 0)
        }
        .frame(height: UIScreen.main.bounds.height)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16,
                style: .continuous
            )
        )
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16,
                style: .continuous
            )
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.15), radius: 10, y: -3)
        )
    }
}

// MARK: - Handle Bar

struct HandleBar: View {
    var body: some View {
        Capsule()
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
    }
}

// MARK: - Sheet Header

struct SheetHeader: View {
    let tacoCount: Int
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(tacoCount) nearby")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tacos...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused(isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Filter Chips Row

struct FilterChipsRow: View {
    @Binding var filter: FilterState
    @Binding var showFavoritesOnly: Bool
    let favoritesCount: Int
    let hasActiveFilters: Bool
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "♥ \(favoritesCount)",
                    isActive: showFavoritesOnly
                ) {
                    HapticManager.selection()
                    showFavoritesOnly.toggle()
                }

                FilterChip(
                    label: "Sort: \(filter.sortBy.rawValue)",
                    isActive: true
                ) {
                    HapticManager.selection()
                    let allCases = SortOption.allCases
                    if let idx = allCases.firstIndex(of: filter.sortBy) {
                        let next = allCases[(allCases.distance(from: allCases.startIndex, to: idx) + 1) % allCases.count]
                        filter.sortBy = next
                    }
                }

                ForEach(PriceFilter.allCases.filter { $0 != .any }) { price in
                    FilterChip(
                        label: price.label,
                        isActive: filter.priceFilter == price
                    ) {
                        HapticManager.selection()
                        filter.priceFilter = filter.priceFilter == price ? .any : price
                    }
                }

                FilterChip(
                    label: "Open Now",
                    isActive: filter.openNowOnly
                ) {
                    HapticManager.selection()
                    filter.openNowOnly.toggle()
                }

                FilterChip(
                    label: filter.minRating > 0 ? "\(String(format: "%.0f", filter.minRating))+ ⭐" : "Rating",
                    isActive: filter.minRating > 0
                ) {
                    HapticManager.selection()
                    let steps: [Double] = [0, 3, 3.5, 4, 4.5]
                    if let idx = steps.firstIndex(of: filter.minRating) {
                        filter.minRating = steps[(idx + 1) % steps.count]
                    } else {
                        filter.minRating = 3
                    }
                }

                if hasActiveFilters {
                    Button {
                        HapticManager.notification(.warning)
                        withAnimation {
                            filter = FilterState()
                            filter.sortBy = settingsManager.defaultSortOrder
                            filter.openNowOnly = settingsManager.defaultOpenNowOnly
                            filter.minRating = settingsManager.defaultMinRating
                            filter.priceFilter = settingsManager.defaultPriceFilter
                            showFavoritesOnly = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? Color.tacoOrange : Color(.systemGray5), in: Capsule())
                .foregroundColor(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selected Taco Section

struct SelectedTacoSection: View {
    let taco: TacoLocation
    let userLocation: CLLocationCoordinate2D
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    let onDetailsTap: () -> Void
    let onDismiss: () -> Void
    var distanceUnit: DistanceUnit = .miles

    var distance: Double {
        DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: distanceUnit)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Hero photo or placeholder
                Group {
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
                    } else {
                        PlaceholderImage(name: taco.name)
                    }
                }
                .frame(width: 130, height: 130)
                .cornerRadius(14)
                .clipped()

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(taco.name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)

                        if taco.isOpenNow {
                            OpenBadge()
                        }

                        Spacer(minLength: 0)

                        // Dismiss button
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .frame(width: 22, height: 22)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 6) {
                        RatingBadge(rating: taco.rating)
                        Text(taco.priceString)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.tacoGreen)
                        Text(taco.cuisine)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(String(format: "%.1f", distance)) \(distanceUnit.abbreviation)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    // Action row
                    HStack(spacing: 8) {
                        Button(action: onFavoriteToggle) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.body)
                                .foregroundColor(isFavorite ? .red : .secondary)
                                .frame(width: 40, height: 36)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: openMaps) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 36)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: openDelivery) {
                            HStack(spacing: 5) {
                                Image(systemName: "bag.fill")
                                    .font(.subheadline)
                                Text("Order")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Color.tacoGreen)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDetailsTap) {
                            Image(systemName: "info.circle.fill")
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 36)
                                .background(Color.tacoOrange)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    func openMaps() {
        HapticManager.impact(.medium)
        let encodedName = taco.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? taco.name
        if let url = URL(string: "maps://maps.apple.com/?q=\(encodedName)&ll=\(taco.latitude),\(taco.longitude)") {
            UIApplication.shared.open(url)
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
