import CoreLocation
import Foundation
import MapKit

protocol InterestingPlaceProviding: Sendable {
    func places(near coordinate: Coordinate, radius: CLLocationDistance) async throws -> [InterestingPlace]
}

enum PlaceProviderError: LocalizedError {
    case noInterestingPlaces

    var errorDescription: String? {
        "We couldn't find enough interesting places here. Try a nearby landmark or city center."
    }
}

struct CompositePlaceProvider: InterestingPlaceProviding {
    private let curated = ChicagoPlaceProvider()
    private let wikipedia = WikipediaPlaceProvider()
    private let apple = ApplePlaceProvider()

    func places(near coordinate: Coordinate, radius: CLLocationDistance) async throws -> [InterestingPlace] {
        let curatedPlaces = await curated.places(near: coordinate, radius: radius)
        if curatedPlaces.count >= 4 { return curatedPlaces }

        let wikipediaPlaces = (try? await wikipedia.places(near: coordinate, radius: radius)) ?? []
        if wikipediaPlaces.count >= 7 { return wikipediaPlaces }

        let applePlaces = (try? await apple.places(near: coordinate, radius: radius)) ?? []
        let combined = deduplicated(wikipediaPlaces + applePlaces)
        guard combined.count >= 4 else { throw PlaceProviderError.noInterestingPlaces }
        return combined
    }

    private func deduplicated(_ places: [InterestingPlace]) -> [InterestingPlace] {
        var result: [InterestingPlace] = []
        for place in places {
            let duplicate = result.contains {
                $0.name.localizedCaseInsensitiveCompare(place.name) == .orderedSame ||
                $0.coordinate.distance(to: place.coordinate) < 35
            }
            if !duplicate { result.append(place) }
        }
        return result
    }
}

struct ChicagoPlaceProvider: InterestingPlaceProviding {
    private let all: [InterestingPlace] = [
        .init(name: "Chicago Cultural Center", coordinate: .init(latitude: 41.8838, longitude: -87.6249), kind: .architecture, reason: "Look up for the world's largest Tiffany glass dome.", detail: "This former public library is a lavish civic interior of mosaics, marble, and stained glass. Enter from Washington Street when open.", source: "One Mile editorial sample"),
        .init(name: "Cloud Gate", coordinate: .init(latitude: 41.8827, longitude: -87.6233), kind: .art, reason: "Chicago's skyline bends across a seamless mirrored surface.", detail: "Anish Kapoor's 110-ton sculpture—better known as “The Bean”—turns the city and everyone around it into a shifting panorama.", source: "One Mile editorial sample"),
        .init(name: "Lurie Garden", coordinate: .init(latitude: 41.8812, longitude: -87.6217), kind: .park, reason: "A quiet, four-season prairie hidden inside Millennium Park.", detail: "The garden's dark and light plates interpret Chicago's transformation from marshland to city, with planting designed by Piet Oudolf.", source: "One Mile editorial sample"),
        .init(name: "Crown Fountain", coordinate: .init(latitude: 41.8811, longitude: -87.6237), kind: .art, reason: "A fountain made from a thousand faces of Chicago.", detail: "Two glass-brick towers project portraits of residents across a shallow reflecting pool. In warmer months, water appears to pour from the faces.", source: "One Mile editorial sample"),
        .init(name: "Historic Route 66 Start", coordinate: .init(latitude: 41.8792, longitude: -87.6248), kind: .history, reason: "The legendary road west once began at this downtown corner.", detail: "A modest sign marks the eastern start of Route 66, the highway that linked Chicago and Santa Monica from 1926.", source: "One Mile editorial sample"),
        .init(name: "The Rookery", coordinate: .init(latitude: 41.8790, longitude: -87.6314), kind: .architecture, reason: "A luminous Frank Lloyd Wright lobby inside an early skyscraper.", detail: "Burnham and Root completed the building in 1888. Wright remodeled its central light court with white marble and geometric ornament in 1905.", source: "One Mile editorial sample"),
        .init(name: "Calder's Flamingo", coordinate: .init(latitude: 41.8788, longitude: -87.6296), kind: .art, reason: "A 53-foot vermilion curve breaks through a severe federal plaza.", detail: "Alexander Calder designed this 1974 steel stabile to contrast with the dark, rectilinear buildings of Mies van der Rohe.", source: "One Mile editorial sample"),
        .init(name: "Monadnock Building", coordinate: .init(latitude: 41.8776, longitude: -87.6291), kind: .architecture, reason: "See how tall a building can get using load-bearing brick.", detail: "Its northern half is among the last and tallest masonry skyscrapers, with walls roughly six feet thick at the base.", source: "One Mile editorial sample"),
        .init(name: "Marquette Building Lobby", coordinate: .init(latitude: 41.8807, longitude: -87.6297), kind: .history, reason: "Tiny mosaics turn an office lobby into an illustrated history.", detail: "The 1895 lobby pairs bronze reliefs with Tiffany mosaics depicting Jacques Marquette's expeditions. Public access varies by building hours.", source: "One Mile editorial sample"),
        .init(name: "Chicago Riverwalk Confluence", coordinate: .init(latitude: 41.8867, longitude: -87.6317), kind: .viewpoint, reason: "Stand where the river splits and the city's architecture opens up.", detail: "The confluence offers long views down all three river branches and an unusually clear reading of Chicago's layered bridges and towers.", source: "One Mile editorial sample")
    ]

    func places(near coordinate: Coordinate, radius: CLLocationDistance) async -> [InterestingPlace] {
        all.filter { $0.coordinate.distance(to: coordinate) <= max(radius, 1_500) }
    }
}

struct ApplePlaceProvider: InterestingPlaceProviding {
    func places(near coordinate: Coordinate, radius: CLLocationDistance) async throws -> [InterestingPlace] {
        var found: [InterestingPlace] = []
        for query in ["landmark", "museum", "historic site", "public art", "park"] {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: coordinate.clLocation,
                latitudinalMeters: radius * 2,
                longitudinalMeters: radius * 2
            )
            let response = try await MKLocalSearch(request: request).start()
            for item in response.mapItems.prefix(4) {
                guard let name = item.name else { continue }
                let kind = kind(for: query)
                found.append(.init(
                    name: name,
                    coordinate: Coordinate(item.placemark.coordinate),
                    kind: kind,
                    reason: reason(for: kind),
                    detail: item.placemark.title.map { "A nearby \(query) at \($0). Details are supplied by Apple Maps." }
                        ?? "A nearby place surfaced by Apple Maps.",
                    source: "Apple Maps"
                ))
            }
        }
        let unique = Dictionary(grouping: found, by: { $0.name.lowercased() }).compactMap(\.value.first)
        guard unique.count >= 4 else { throw PlaceProviderError.noInterestingPlaces }
        return unique
    }

    private func kind(for query: String) -> PlaceKind {
        switch query {
        case "park": .park
        case "public art": .art
        case "historic site": .history
        default: .local
        }
    }

    private func reason(for kind: PlaceKind) -> String {
        switch kind {
        case .park: "A nearby green space worth a short detour."
        case .art: "Public art that adds character to this part of town."
        case .history: "A nearby place connected to local history."
        default: "A locally notable place surfaced by Apple Maps."
        }
    }
}
