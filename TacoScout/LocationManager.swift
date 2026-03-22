import CoreLocation
import Combine
import os.log

private let locationLogger = Logger(subsystem: "com.tacoscout.app", category: "LocationManager")

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = true

    private let locationManager = CLLocationManager()
    private var retryCount = 0
    private let maxRetries = 3

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestLocation() {
        retryCount = 0
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            DispatchQueue.main.async {
                self.userLocation = location.coordinate
                self.isLoading = false
            }
            if let shared = UserDefaults(suiteName: "group.com.tacoscout.app") {
                shared.set(location.coordinate.latitude, forKey: "widgetLastLatitude")
                shared.set(location.coordinate.longitude, forKey: "widgetLastLongitude")
            }
            // Stop continuous updates once we have a fix — saves battery
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationLogger.error("Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
        }
        // Only retry if we never got a location, and cap retries
        if userLocation == nil && retryCount < maxRetries {
            retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                locationLogger.debug("Retrying location request (\(self.retryCount)/\(self.maxRetries))...")
                manager.startUpdatingLocation()
            }
        } else if userLocation == nil {
            locationLogger.warning("Location failed after \(self.maxRetries) retries — giving up")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            }
        }
    }
}
