import MapKit

struct DistanceCalculator {
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distanceInMeters = fromLocation.distance(from: toLocation)
        let distanceInMiles = distanceInMeters / 1609.34
        return round(distanceInMiles * 10) / 10
    }

    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, unit: DistanceUnit) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distanceInMeters = fromLocation.distance(from: toLocation)
        let converted = distanceInMeters / unit.conversionFactor
        return round(converted * 10) / 10
    }
}
