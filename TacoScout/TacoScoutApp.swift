import SwiftUI
import WidgetKit

@main
struct TacoScoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { syncSharedData() }
        }
    }

    private func syncSharedData() {
        guard let shared = UserDefaults(suiteName: "group.com.tacoscout.app") else { return }
        if let key = Bundle.main.infoDictionary?["GOOGLE_PLACES_API_KEY"] as? String, !key.isEmpty {
            shared.set(key, forKey: "widgetGooglePlacesAPIKey")
        }
        shared.set(UserDefaults.standard.integer(forKey: "settingsSearchRadius"), forKey: "settingsSearchRadius")
        shared.set(UserDefaults.standard.string(forKey: "settingsDistanceUnit") ?? "Miles", forKey: "settingsDistanceUnit")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
