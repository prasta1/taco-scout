import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - Shared Data

struct SharedDataManager {
    static let appGroupID = "group.com.tacoscout.app"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var lastLocation: CLLocationCoordinate2D? {
        guard let defaults = sharedDefaults else { return nil }
        let lat = defaults.double(forKey: "widgetLastLatitude")
        let lon = defaults.double(forKey: "widgetLastLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static var searchRadiusMeters: Double {
        guard let defaults = sharedDefaults else { return 25 * 1609.34 }
        let raw = defaults.integer(forKey: "settingsSearchRadius")
        let miles = raw > 0 ? raw : 25
        return Double(miles) * 1609.34
    }

    static var distanceUnit: DistanceUnit {
        let raw = sharedDefaults?.string(forKey: "settingsDistanceUnit") ?? "Miles"
        return DistanceUnit(rawValue: raw) ?? .miles
    }
}

// MARK: - Timeline Entry

struct TacoWidgetEntry: TimelineEntry {
    let date: Date
    let tacos: [TacoLocation]
    let userLocation: CLLocationCoordinate2D?
    let distanceUnit: DistanceUnit
    let isPlaceholder: Bool
}

// MARK: - Timeline Provider

struct TacoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TacoWidgetEntry {
        TacoWidgetEntry(date: .now, tacos: [], userLocation: nil, distanceUnit: .miles, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TacoWidgetEntry) -> Void) {
        completion(TacoWidgetEntry(date: .now, tacos: [], userLocation: nil, distanceUnit: .miles, isPlaceholder: true))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TacoWidgetEntry>) -> Void) {
        Task {
            let unit = SharedDataManager.distanceUnit

            guard let location = SharedDataManager.lastLocation else {
                let entry = TacoWidgetEntry(date: .now, tacos: [], userLocation: nil, distanceUnit: unit, isPlaceholder: false)
                completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
                return
            }

            let tacos = await TacoService.searchNearbyTacos(location: location, radiusMeters: SharedDataManager.searchRadiusMeters)
            let sorted = tacos.sorted { taco1, taco2 in
                DistanceCalculator.distance(from: location, to: taco1.coordinate) <
                DistanceCalculator.distance(from: location, to: taco2.coordinate)
            }

            let entry = TacoWidgetEntry(
                date: .now,
                tacos: Array(sorted.prefix(3)),
                userLocation: location,
                distanceUnit: unit,
                isPlaceholder: false
            )
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }
}
