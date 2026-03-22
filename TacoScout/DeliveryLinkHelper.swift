import Foundation
import UIKit

/// Builds deep links to delivery apps (DoorDash, Uber Eats, Grubhub) for a given restaurant.
/// Falls back to web search URLs when apps aren't installed.
enum DeliveryLinkHelper {

    /// A delivery service with its app URL scheme and web fallback.
    struct DeliveryOption {
        let name: String
        let icon: String      // SF Symbol name
        let appURL: URL?      // Deep link into the app
        let webURL: URL       // Fallback web URL

        /// Whether the native app is installed (can be opened).
        var isAppInstalled: Bool {
            guard let appURL else { return false }
            return UIApplication.shared.canOpenURL(appURL)
        }

        /// The best URL to open — native app if installed, otherwise web.
        var bestURL: URL {
            if let appURL, isAppInstalled {
                return appURL
            }
            return webURL
        }
    }

    /// Returns delivery options for a restaurant, ordered by preference.
    /// Uses the restaurant name and coordinates to build search links.
    static func options(for name: String, latitude: Double, longitude: Double) -> [DeliveryOption] {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name

        return [
            // DoorDash — universal link search
            DeliveryOption(
                name: "DoorDash",
                icon: "car.fill",
                appURL: URL(string: "doordash://store/search/\(encodedName)"),
                webURL: URL(string: "https://www.doordash.com/search/store/\(encodedName)/?lat=\(latitude)&lng=\(longitude)")!
            ),
            // Uber Eats — universal link with location
            DeliveryOption(
                name: "Uber Eats",
                icon: "bag.fill",
                appURL: URL(string: "ubereats://search?q=\(encodedName)"),
                webURL: URL(string: "https://www.ubereats.com/search?q=\(encodedName)&pl=\(latitude)%2C\(longitude)")!
            ),
            // Grubhub — web search with location
            DeliveryOption(
                name: "Grubhub",
                icon: "fork.knife",
                appURL: URL(string: "grubhub://search/\(encodedName)"),
                webURL: URL(string: "https://www.grubhub.com/search?queryText=\(encodedName)&latitude=\(latitude)&longitude=\(longitude)")!
            ),
        ]
    }

    /// Opens the first available delivery app, or falls back to web.
    /// Returns the name of the service that was opened.
    @discardableResult
    static func openBestOption(for name: String, latitude: Double, longitude: Double) -> String {
        let opts = options(for: name, latitude: latitude, longitude: longitude)

        // Prefer an installed app
        if let installed = opts.first(where: { $0.isAppInstalled }) {
            UIApplication.shared.open(installed.bestURL)
            return installed.name
        }

        // No app installed — open DoorDash web as default
        let fallback = opts[0]
        UIApplication.shared.open(fallback.webURL)
        return fallback.name
    }
}
