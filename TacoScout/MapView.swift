import SwiftUI
import MapKit

// MARK: - MapZoomController

class MapZoomController: NSObject {
    var mapView: MKMapView?
    var coordinator: MapView.Coordinator?

    func zoomIn() {
        guard let mapView = mapView else { return }
        var region = mapView.region
        region.span.latitudeDelta *= 0.5
        region.span.longitudeDelta *= 0.5
        mapView.setRegion(region, animated: true)
    }

    func zoomOut() {
        guard let mapView = mapView else { return }
        var region = mapView.region
        region.span.latitudeDelta *= 2.0
        region.span.longitudeDelta *= 2.0
        mapView.setRegion(region, animated: true)
    }

    func centerOnUserLocation(_ userLocation: CLLocationCoordinate2D) {
        guard let mapView = mapView else { return }
        let region = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        mapView.setRegion(region, animated: true)
    }

    func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard let mapView = mapView else { return }
        let currentSpan = mapView.region.span
        let region = MKCoordinateRegion(center: coordinate, span: currentSpan)
        mapView.setRegion(region, animated: true)
    }
}

struct MapView: UIViewRepresentable {
    let userLocation: CLLocationCoordinate2D?
    let tacos: [TacoLocation]
    @Binding var selectedTaco: TacoLocation?
    let onTacoSelect: (TacoLocation) -> Void
    var zoomController: MapZoomController?
    /// Bottom inset for the visible map area (accounts for the bottom sheet in portrait).
    var bottomInset: CGFloat = 0
    /// Leading inset for the visible map area (accounts for the side panel in landscape).
    var leadingInset: CGFloat = 0

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        // Store mapView reference in the provided controller
        zoomController?.mapView = mapView
        zoomController?.coordinator = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Store mapView reference for zoom controls
        zoomController?.mapView = mapView
        zoomController?.coordinator = context.coordinator

        // Tell MapKit about the visible area so centering accounts for the sheet/side panel
        let newMargins = UIEdgeInsets(top: 0, left: leadingInset, bottom: bottomInset, right: 0)
        if mapView.layoutMargins != newMargins {
            mapView.layoutMargins = newMargins
        }

        // Only update annotations if the taco list actually changed (IDs or content)
        let existingTacoAnnotations = mapView.annotations.compactMap { $0 as? TacoAnnotation }
        let existingIDs = Set(existingTacoAnnotations.map { $0.taco.id })
        let newIDs = Set(tacos.map { $0.id })

        let contentChanged = existingIDs != newIDs || existingTacoAnnotations.contains { annotation in
            guard let match = tacos.first(where: { $0.id == annotation.taco.id }) else { return true }
            return match.name != annotation.taco.name
                || match.rating != annotation.taco.rating
                || match.latitude != annotation.taco.latitude
                || match.longitude != annotation.taco.longitude
        }

        if contentChanged {
            // Remove old annotations
            if !existingTacoAnnotations.isEmpty {
                mapView.removeAnnotations(existingTacoAnnotations)
            }
            // Add new annotations
            if !tacos.isEmpty {
                let newAnnotations = tacos.map { TacoAnnotation(taco: $0) }
                mapView.addAnnotations(newAnnotations)
            }
        }

        // Center on user location (only once when first received)
        if let userLocation = userLocation, !context.coordinator.hasSetInitialRegion {
            let region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            mapView.setRegion(region, animated: false) // Use animated: false for faster initial load
            context.coordinator.hasSetInitialRegion = true
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self, onTacoSelect: onTacoSelect)
        return coordinator
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var onTacoSelect: (TacoLocation) -> Void
        var hasSetInitialRegion = false

        init(_ parent: MapView, onTacoSelect: @escaping (TacoLocation) -> Void) {
            self.parent = parent
            self.onTacoSelect = onTacoSelect
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let tacoAnnotation = annotation as? TacoAnnotation else { return nil }

            let identifier = "tacoAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: tacoAnnotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                // Set up gesture recognizer for faster interaction
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(annotationTapped(_:)))
                annotationView?.addGestureRecognizer(tapGesture)
            } else {
                annotationView?.annotation = tacoAnnotation
            }

            // Always re-apply custom appearance (dequeued views can lose these)
            annotationView?.markerTintColor = .systemOrange
            annotationView?.glyphText = "🌮"

            return annotationView
        }

        @objc func annotationTapped(_ gesture: UITapGestureRecognizer) {
            if let annotationView = gesture.view as? MKAnnotationView,
               let tacoAnnotation = annotationView.annotation as? TacoAnnotation {
                onTacoSelect(tacoAnnotation.taco)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let tacoAnnotation = view.annotation as? TacoAnnotation {
                onTacoSelect(tacoAnnotation.taco)
            }
        }
    }
}

class TacoAnnotation: NSObject, MKAnnotation {
    dynamic let coordinate: CLLocationCoordinate2D
    let taco: TacoLocation

    init(taco: TacoLocation) {
        self.taco = taco
        self.coordinate = taco.coordinate
        super.init()
    }

    var title: String? {
        taco.name
    }

    var subtitle: String? {
        "\(taco.cuisine) • ⭐ \(String(format: "%.1f", taco.rating))"
    }
}

#Preview {
    MapView(
        userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        tacos: [],
        selectedTaco: .constant(nil),
        onTacoSelect: { _ in }
    )
}
