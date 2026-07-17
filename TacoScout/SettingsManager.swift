import Foundation
import Observation
import WidgetKit

// MARK: - Settings Enums

enum SearchRadius: Int, CaseIterable, Identifiable {
    case one = 1
    case three = 3
    case five = 5
    case ten = 10
    case twenty = 20

    var id: Int { rawValue }

    var meters: Double {
        Double(rawValue) * 1609.34
    }

    func label(unit: DistanceUnit) -> String {
        switch unit {
        case .miles:
            if self == .one { return "<1 mi" }
            return "\(rawValue) mi"
        case .kilometers:
            let km = Int(Double(rawValue) * 1.60934)
            if self == .one { return "<2 km" }
            return "\(km) km"
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles = "Miles"
    case kilometers = "Kilometers"

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }

    var conversionFactor: Double {
        switch self {
        case .miles: return 1609.34
        case .kilometers: return 1000.0
        }
    }
}

// MARK: - Settings Manager

@Observable
@MainActor
final class SettingsManager {
    var searchRadius: SearchRadius {
        didSet {
            UserDefaults.standard.set(searchRadius.rawValue, forKey: Keys.searchRadius)
            UserDefaults(suiteName: "group.com.tacoscout.app")?.set(searchRadius.rawValue, forKey: Keys.searchRadius)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
            UserDefaults(suiteName: "group.com.tacoscout.app")?.set(distanceUnit.rawValue, forKey: Keys.distanceUnit)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
            HapticManager.enabled = hapticsEnabled
        }
    }

    var defaultSortOrder: SortOption {
        didSet { UserDefaults.standard.set(defaultSortOrder.rawValue, forKey: Keys.defaultSort) }
    }

    var soundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundsEnabled, forKey: Keys.soundsEnabled)
        }
    }

    var defaultOpenNowOnly: Bool {
        didSet { UserDefaults.standard.set(defaultOpenNowOnly, forKey: Keys.defaultOpenNow) }
    }

    var defaultMinRating: Double {
        didSet { UserDefaults.standard.set(defaultMinRating, forKey: Keys.defaultMinRating) }
    }

    var defaultPriceFilter: PriceFilter {
        didSet { UserDefaults.standard.set(defaultPriceFilter.rawValue, forKey: Keys.defaultPriceFilter) }
    }

    private enum Keys {
        static let searchRadius = "settingsSearchRadius"
        static let distanceUnit = "settingsDistanceUnit"
        static let hapticsEnabled = "settingsHapticsEnabled"
        static let defaultSort = "settingsDefaultSort"
        static let soundsEnabled = "settingsSoundsEnabled"
        static let defaultOpenNow = "settingsDefaultOpenNow"
        static let defaultMinRating = "settingsDefaultMinRating"
        static let defaultPriceFilter = "settingsDefaultPriceFilter"
    }

    init() {
        let radiusRaw = UserDefaults.standard.integer(forKey: Keys.searchRadius)
        self.searchRadius = SearchRadius(rawValue: radiusRaw) ?? .five

        let unitRaw = UserDefaults.standard.string(forKey: Keys.distanceUnit) ?? ""
        self.distanceUnit = DistanceUnit(rawValue: unitRaw) ?? .miles

        let haptics: Bool
        if UserDefaults.standard.object(forKey: Keys.hapticsEnabled) != nil {
            haptics = UserDefaults.standard.bool(forKey: Keys.hapticsEnabled)
        } else {
            haptics = true
        }
        self.hapticsEnabled = haptics

        let sounds: Bool
        if UserDefaults.standard.object(forKey: Keys.soundsEnabled) != nil {
            sounds = UserDefaults.standard.bool(forKey: Keys.soundsEnabled)
        } else {
            sounds = true
        }
        self.soundsEnabled = sounds

        let sortRaw = UserDefaults.standard.string(forKey: Keys.defaultSort) ?? ""
        self.defaultSortOrder = SortOption(rawValue: sortRaw) ?? .distance

        self.defaultOpenNowOnly = UserDefaults.standard.bool(forKey: Keys.defaultOpenNow)

        let ratingRaw = UserDefaults.standard.double(forKey: Keys.defaultMinRating)
        self.defaultMinRating = ratingRaw // defaults to 0 (any)

        let priceRaw = UserDefaults.standard.integer(forKey: Keys.defaultPriceFilter)
        self.defaultPriceFilter = PriceFilter(rawValue: priceRaw) ?? .any

        HapticManager.enabled = haptics
    }

    /// A FilterState seeded from the user's saved defaults, including the search radius.
    /// Single source of truth — every "reset/sync filters" path must go through this so
    /// the active-filter badge math (which compares against these values) stays consistent.
    func defaultFilter() -> FilterState {
        var filter = FilterState()
        filter.sortBy = defaultSortOrder
        filter.openNowOnly = defaultOpenNowOnly
        filter.minRating = defaultMinRating
        filter.priceFilter = defaultPriceFilter
        filter.maxDistance = Double(searchRadius.rawValue)
        return filter
    }

    func resetFilterDefaults() {
        searchRadius = .five
        defaultSortOrder = .distance
        defaultOpenNowOnly = false
        defaultMinRating = 0
        defaultPriceFilter = .any
    }
}
