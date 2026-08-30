import CoreLocation
import Foundation
import MapKit

protocol WalkingRouteBuilding: Sendable {
    func route(from start: Coordinate, through stops: [InterestingPlace]) async -> ([Coordinate], CLLocationDistance)
}

struct MapKitWalkingRouteBuilder: WalkingRouteBuilding {
    func route(from start: Coordinate, through stops: [InterestingPlace]) async -> ([Coordinate], CLLocationDistance) {
        let waypoints = [start] + stops.map(\.coordinate) + [start]
        var coordinates: [Coordinate] = []
        var distance: CLLocationDistance = 0

        for pair in zip(waypoints, waypoints.dropFirst()) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: pair.0.clLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: pair.1.clLocation))
            request.transportType = .walking
            do {
                guard let route = try await MKDirections(request: request).calculate().routes.first else { continue }
                distance += route.distance
                var values = Array(repeating: CLLocationCoordinate2D(), count: route.polyline.pointCount)
                route.polyline.getCoordinates(&values, range: NSRange(location: 0, length: route.polyline.pointCount))
                coordinates.append(contentsOf: values.map(Coordinate.init))
            } catch {
                distance += pair.0.distance(to: pair.1)
                coordinates.append(contentsOf: [pair.0, pair.1])
            }
        }
        return (coordinates.isEmpty ? waypoints : coordinates, distance)
    }
}

struct RouteGenerator: Sendable {
    let provider: InterestingPlaceProviding
    let routeBuilder: WalkingRouteBuilding

    func generate(from start: Coordinate, name: String, duration: WalkDuration) async throws -> WalkPlan {
        let candidates = try await provider.places(near: start, radius: duration.targetMeters / 2)
            .filter { $0.coordinate.distance(to: start) > 35 }
        guard candidates.count >= 4 else { throw PlaceProviderError.noInterestingPlaces }

        let chosen = selectLoop(from: start, candidates: candidates, count: duration.stopCount)
        let (coordinates, distance) = await routeBuilder.route(from: start, through: chosen)
        return WalkPlan(
            id: UUID(), createdAt: .now, startName: name, start: start,
            duration: duration, stops: chosen, routeCoordinates: coordinates,
            distanceMeters: distance
        )
    }

    func selectLoop(from start: Coordinate, candidates: [InterestingPlace], count: Int) -> [InterestingPlace] {
        let sorted = candidates.sorted {
            polarAngle(of: $0.coordinate, around: start) < polarAngle(of: $1.coordinate, around: start)
        }
        guard sorted.count > count else { return sorted }

        // Sample evenly around the start, favoring a loop over nearest-neighbor backtracking.
        let stride = Double(sorted.count) / Double(count)
        return (0..<count).map { sorted[min(Int((Double($0) * stride).rounded()), sorted.count - 1)] }
    }

    private func polarAngle(of point: Coordinate, around center: Coordinate) -> Double {
        atan2(point.latitude - center.latitude, point.longitude - center.longitude)
    }
}

