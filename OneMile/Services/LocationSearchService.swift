import Foundation
import MapKit

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
    }
}

@MainActor
final class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published private(set) var results: [SearchResult] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.prefix(8).map {
            SearchResult(title: $0.title, subtitle: $0.subtitle, completion: $0)
        }
        Task { @MainActor in results = mapped }
    }

    func resolve(_ result: SearchResult) async throws -> (Coordinate, String) {
        let request = MKLocalSearch.Request(completion: result.completion)
        guard let item = try await MKLocalSearch(request: request).start().mapItems.first else {
            throw PlaceProviderError.noInterestingPlaces
        }
        query = ""
        return (Coordinate(item.placemark.coordinate), item.name ?? result.title)
    }
}

