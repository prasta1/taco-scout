import Foundation
import MapKit
import os.log

private let logger = Logger(subsystem: "com.tacoscout.app", category: "TacoService")

struct TacoService {

    // MARK: - Search via Google Places API

    static func searchNearbyTacos(location: CLLocationCoordinate2D, radiusMeters: Double = 50000) async -> [TacoLocation] {
        let start = Date()

        if let googleTacos = await searchNearbyTacosWithGooglePlaces(location: location, radiusMeters: radiusMeters),
           !googleTacos.isEmpty {
            logger.debug("⏱️ [GOOGLE] Returned \(googleTacos.count) tacos in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
            return googleTacos
        }
        logger.debug("⏱️ [GOOGLE] No results or failed in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")

        // No results available
        logger.debug("⏱️ [NO RESULTS] Google Places returned nothing after \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        return []
    }

    // MARK: - Google Places API (New) — Nearby Search

    private static func searchNearbyTacosWithGooglePlaces(location: CLLocationCoordinate2D, radiusMeters: Double) async -> [TacoLocation]? {
        guard let apiKey = getGooglePlacesAPIKey() else {
            logger.warning("Google Places API key not configured. Skipping Google Places search.")
            return nil
        }

        let url = URL(string: "https://places.googleapis.com/v1/places:searchNearby")!

        // Build the JSON request body
        // Nearby Search (New) doesn't support keyword/text — use type filtering
        let requestBody: [String: Any] = [
            "includedTypes": ["mexican_restaurant"],
            "maxResultCount": 20,
            "rankPreference": "DISTANCE",
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": location.latitude,
                        "longitude": location.longitude
                    ],
                    "radius": min(radiusMeters, 50000.0) // Google Places API max is 50km
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            logger.error("Failed to serialize request body")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.timeoutInterval = 6.0 // safety net; hard deadline enforced below
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        // Field mask — only request fields we actually use (controls billing + payload size)
        request.setValue(
            "places.id,places.displayName,places.location,places.rating,places.priceLevel,places.shortFormattedAddress,places.types,places.photos",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        // Race the network request against a hard 5s wall-clock deadline
        let timeoutNanos: UInt64 = 5_000_000_000

        return await withTaskGroup(of: [TacoLocation]?.self) { group in
            // Task 1: The actual API call
            group.addTask {
                do {
                    logger.debug("Attempting Google Places API (New) query...")
                    let (data, response) = try await URLSession.shared.data(for: request)

                    if let httpResponse = response as? HTTPURLResponse {
                        logger.debug("Google Places API Response Status: \(httpResponse.statusCode)")
                        if httpResponse.statusCode != 200 {
                            logger.error("Google Places API returned status code: \(httpResponse.statusCode)")
                            if let responseStr = String(data: data, encoding: .utf8) {
                                logger.error("Error response: \(responseStr.prefix(500))")
                            }
                            return nil
                        }
                    }

                    let placesResponse = try JSONDecoder().decode(PlacesNewResponse.self, from: data)
                    let places = placesResponse.places ?? []
                    logger.debug("Google Places (New) returned \(places.count) results")

                    let tacos: [TacoLocation] = places.map { place in
                        TacoLocation(
                            id: place.id,
                            name: place.displayName.text,
                            latitude: place.location.latitude,
                            longitude: place.location.longitude,
                            cuisine: place.types?.first?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Mexican Restaurant",
                            rating: place.rating ?? 4.0,
                            address: place.shortFormattedAddress ?? "",
                            priceLevel: place.priceLevelInt,
                            photos: place.photos?.prefix(5).compactMap { photo in
                                "https://places.googleapis.com/v1/\(photo.name)/media?maxWidthPx=400&key=\(apiKey)"
                            } ?? [],
                            reviews: [],
                            hours: nil,
                            phone: nil,
                            website: nil
                        )
                    }
                    return tacos
                } catch {
                    logger.error("Google Places API Error: \(error.localizedDescription)")
                    return nil
                }
            }

            // Task 2: Hard wall-clock timeout
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanos)
                logger.debug("⏱️ [TIMEOUT] Google Places hard 5s deadline hit")
                return nil
            }

            // Return the first result — either data or timeout
            for await result in group {
                if let tacos = result {
                    group.cancelAll()
                    return tacos
                }
                group.cancelAll()
                return nil
            }
            return nil
        }
    }

    // MARK: - Configuration

    private static func getGooglePlacesAPIKey() -> String? {
        if let key = Bundle.main.infoDictionary?["GOOGLE_PLACES_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        if let key = UserDefaults(suiteName: "group.com.tacoscout.app")?.string(forKey: "widgetGooglePlacesAPIKey"), !key.isEmpty {
            return key
        }
        return nil
    }
    
    // MARK: - Sorting
    
    static func sortedByDistance(tacos: [TacoLocation], from userLocation: CLLocationCoordinate2D) -> [TacoLocation] {
        tacos.sorted { taco1, taco2 in
            let distance1 = DistanceCalculator.distance(from: userLocation, to: taco1.coordinate)
            let distance2 = DistanceCalculator.distance(from: userLocation, to: taco2.coordinate)
            return distance1 < distance2
        }
    }
    
    static func sorted(tacos: [TacoLocation], by option: SortOption, from userLocation: CLLocationCoordinate2D) -> [TacoLocation] {
        switch option {
        case .distance:
            return sortedByDistance(tacos: tacos, from: userLocation)
        case .rating:
            return tacos.sorted { $0.rating > $1.rating }
        case .price:
            return tacos.sorted { $0.priceLevel < $1.priceLevel }
        }
    }
    
    // MARK: - Filtering
    
    static func filterByDistance(tacos: [TacoLocation], from userLocation: CLLocationCoordinate2D, maxMiles: Double = 5.0) -> [TacoLocation] {
        tacos.filter { taco in
            let distance = DistanceCalculator.distance(from: userLocation, to: taco.coordinate)
            return distance <= maxMiles
        }
    }
    
    static func filtered(tacos: [TacoLocation], with filter: FilterState, from userLocation: CLLocationCoordinate2D) -> [TacoLocation] {
        var result = tacos
        
        // Distance filter
        result = filterByDistance(tacos: result, from: userLocation, maxMiles: filter.maxDistance)
        
        // Rating filter
        if filter.minRating > 0 {
            result = result.filter { $0.rating >= filter.minRating }
        }
        
        // Price filter
        if filter.priceFilter != .any {
            result = result.filter { $0.priceLevel == filter.priceFilter.rawValue }
        }
        
        // Open now filter
        if filter.openNowOnly {
            result = result.filter { $0.isOpenNow }
        }
        
        // Sort
        result = sorted(tacos: result, by: filter.sortBy, from: userLocation)
        
        return result
    }
    
    // MARK: - Random Pick ("I'm Feeling Lucky")

    static func randomPick(from tacos: [TacoLocation], minRating: Double = 2.0) -> TacoLocation? {
        let goodOnes = tacos.filter { $0.rating >= minRating }
        return goodOnes.randomElement() ?? tacos.randomElement()
    }

}

// MARK: - Google Places API Service

// Note: The main Google Places API integration is handled in TacoService.searchNearbyTacos().
// This class is kept for potential future use (e.g., place details, photos, etc.)

class PlacesAPIService: ObservableObject {
    static let shared = PlacesAPIService()

    var isConfigured: Bool {
        Bundle.main.infoDictionary?["GOOGLE_PLACES_API_KEY"] != nil
    }
}

// MARK: - Google Places API (New) Response Models

struct PlacesNewResponse: Codable {
    let places: [PlaceNewResult]?
}

struct PlaceNewResult: Codable {
    let id: String
    let displayName: PlaceDisplayName
    let location: PlaceNewCoordinate
    let rating: Double?
    let priceLevel: String?
    let shortFormattedAddress: String?
    let types: [String]?
    let photos: [PlaceNewPhoto]?

    /// Convert the new API's string price level to an integer (1-3) for our model
    var priceLevelInt: Int {
        switch priceLevel {
        case "PRICE_LEVEL_INEXPENSIVE": return 1
        case "PRICE_LEVEL_MODERATE": return 2
        case "PRICE_LEVEL_EXPENSIVE": return 3
        case "PRICE_LEVEL_VERY_EXPENSIVE": return 3
        default: return 2 // default to moderate if unknown/nil
        }
    }
}

struct PlaceDisplayName: Codable {
    let text: String
    let languageCode: String?
}

struct PlaceNewCoordinate: Codable {
    let latitude: Double
    let longitude: Double
}

struct PlaceNewPhoto: Codable {
    let name: String
    let widthPx: Int?
    let heightPx: Int?
}

