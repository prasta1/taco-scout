import Foundation
import UIKit

/// Builds deep links to delivery apps (DoorDash, Uber Eats, Grubhub) for a given restaurant.
/// Falls back to website or phone ordering when delivery apps aren't available.
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

    /// What the caller must do after invoking `order(for:)`.
    enum OrderAction {
        case opened
        case chooseApp([DeliveryOption])
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

    /// Delivery apps currently installed on this device for a given taco.
    static func availableApps(for taco: TacoLocation) -> [DeliveryOption] {
        options(for: taco.name, latitude: taco.latitude, longitude: taco.longitude)
            .filter { $0.isAppInstalled }
    }

    /// Label and icon for an Order button based on the tier chain.
    /// Returns nil when no ordering path is available (no apps, no website, no phone).
    static func buttonConfig(for taco: TacoLocation) -> (label: String, icon: String)? {
        let apps = availableApps(for: taco)
        if apps.count == 1 { return ("Order on \(apps[0].name)", apps[0].icon) }
        if apps.count > 1  { return ("Order", "bag.fill") }
        if taco.website != nil { return ("Order Online", "globe") }
        if taco.phone != nil   { return ("Call to Order", "phone.fill") }
        return nil
    }

    /// Runs the ordering tier chain and returns what the caller must do.
    /// Tier 1–2: installed delivery apps (returns .chooseApp when 2+, opens directly when 1).
    /// Tier 3: restaurant website. Tier 4: phone dialer.
    static func order(for taco: TacoLocation) -> OrderAction {
        let apps = availableApps(for: taco)

        if apps.count > 1 {
            return .chooseApp(apps)
        }
        if let single = apps.first {
            UIApplication.shared.open(single.bestURL)
            return .opened
        }
        if let website = taco.website, let url = URL(string: website) {
            UIApplication.shared.open(url)
            return .opened
        }
        if let phone = taco.phone,
           let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
            UIApplication.shared.open(url)
            return .opened
        }
        return .opened
    }
}
