import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinate: Coordinate?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is off. Search for a starting point instead."
        @unknown default: break
        }
    }

    func startWalkingUpdates() {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.startUpdatingLocation()
    }

    func stopWalkingUpdates() { manager.stopUpdatingLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in coordinate = Coordinate(location.coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if (error as? CLError)?.code != .locationUnknown {
                errorMessage = "Your location isn't available right now. You can still search for a place."
            }
        }
    }
}

