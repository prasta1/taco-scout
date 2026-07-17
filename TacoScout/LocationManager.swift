import CoreLocation
import Observation
import os.log

private let locationLogger = Logger(subsystem: "com.tacoscout.app", category: "LocationManager")

@Observable
@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var userLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var retryCount = 0
    @ObservationIgnored private let maxRetries = 3
    @ObservationIgnored private var locationWaiters: [CheckedContinuation<LocationResult, Never>] = []

    enum LocationResult {
        case coordinate(CLLocationCoordinate2D)
        case denied
    }

    /// Awaits the next location result. Returns immediately if location already available.
    /// Returns .denied if location access is denied/restricted or fails after retries.
    func nextLocation() async -> LocationResult {
        if let loc = userLocation { return .coordinate(loc) }
        if authorizationStatus == .denied || authorizationStatus == .restricted { return .denied }
        return await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
        }
    }

    private func resumeWaiters(with result: LocationResult) {
        let waiters = locationWaiters
        locationWaiters.removeAll()
        for waiter in waiters { waiter.resume(returning: result) }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestLocation() {
        retryCount = 0
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // Already authorized — start immediately
            locationManager.startUpdatingLocation()
        } else if status == .notDetermined {
            // Will trigger locationManagerDidChangeAuthorization, which starts updates
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Denied or restricted
            locationLogger.warning("Location access denied or restricted (status: \(status.rawValue))")
            resumeWaiters(with: .denied)
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use the most recent fix; skip stale cached locations (older than 30s)
        guard let location = locations.last,
              location.timestamp.timeIntervalSinceNow > -30 else { return }

        if let shared = UserDefaults(suiteName: "group.com.tacoscout.app") {
            shared.set(location.coordinate.latitude, forKey: "widgetLastLatitude")
            shared.set(location.coordinate.longitude, forKey: "widgetLastLongitude")
        }

        MainActor.assumeIsolated {
            self.userLocation = location.coordinate
            self.resumeWaiters(with: .coordinate(location.coordinate))
            // Stop continuous updates once we have a fresh fix — saves battery
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationLogger.error("Location error: \(error.localizedDescription)")
        MainActor.assumeIsolated {
            // Only retry if we never got a location, and cap retries
            if self.userLocation == nil && self.retryCount < self.maxRetries {
                self.retryCount += 1
                let attempt = self.retryCount
                let cap = self.maxRetries
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    locationLogger.debug("Retrying location request (\(attempt)/\(cap))...")
                    manager.startUpdatingLocation()
                }
            } else if self.userLocation == nil {
                locationLogger.warning("Location failed after \(self.maxRetries) retries — giving up")
                self.resumeWaiters(with: .denied)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                self.resumeWaiters(with: .denied)
            }
        }
    }
}
