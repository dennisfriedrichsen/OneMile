import CoreLocation
import Foundation

enum WalkDuration: Int, CaseIterable, Codable, Identifiable {
    case thirty = 30
    case sixty = 60
    case ninety = 90

    var id: Int { rawValue }
    var title: String { "\(rawValue) min" }
    var stopCount: Int { self == .thirty ? 4 : (self == .sixty ? 5 : 7) }
    var targetMeters: CLLocationDistance { Double(rawValue) * 68 }
}

enum PlaceKind: String, Codable, CaseIterable {
    case architecture, history, art, park, viewpoint, local

    var symbol: String {
        switch self {
        case .architecture: "building.columns"
        case .history: "clock"
        case .art: "paintpalette"
        case .park: "leaf"
        case .viewpoint: "binoculars"
        case .local: "sparkles"
        }
    }
}

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: Coordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

struct InterestingPlace: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let coordinate: Coordinate
    let kind: PlaceKind
    let reason: String
    let detail: String
    let source: String
    let sourceURL: URL?

    init(
        id: UUID = UUID(), name: String, coordinate: Coordinate,
        kind: PlaceKind, reason: String, detail: String, source: String,
        sourceURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.kind = kind
        self.reason = reason
        self.detail = detail
        self.source = source
        self.sourceURL = sourceURL
    }
}

struct WalkPlan: Identifiable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let startName: String
    let start: Coordinate
    let duration: WalkDuration
    let stops: [InterestingPlace]
    let routeCoordinates: [Coordinate]
    let distanceMeters: CLLocationDistance

    var estimatedMinutes: Int { max(1, Int((distanceMeters / 68).rounded())) }
}

struct CompletedWalk: Identifiable, Codable, Sendable {
    let id: UUID
    let completedAt: Date
    let startName: String
    let duration: WalkDuration
    let distanceMeters: CLLocationDistance
    let stopCount: Int

    init(plan: WalkPlan) {
        id = plan.id
        completedAt = .now
        startName = plan.startName
        duration = plan.duration
        distanceMeters = plan.distanceMeters
        stopCount = plan.stops.count
    }
}
