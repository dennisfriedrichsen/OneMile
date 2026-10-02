import CoreLocation
import Foundation

actor WikipediaPlaceProvider: InterestingPlaceProviding {
    private let session: URLSession
    private let cache: WikipediaPlaceCache
    private let language: String

    init(
        session: URLSession = .shared,
        cacheURL: URL? = nil,
        language: String = "en"
    ) {
        self.session = session
        self.language = language
        let defaultURL = URL.cachesDirectory.appending(path: "wikipedia-nearby.json")
        cache = WikipediaPlaceCache(url: cacheURL ?? defaultURL)
    }

    func places(near coordinate: Coordinate, radius: CLLocationDistance) async throws -> [InterestingPlace] {
        let key = CacheKey(coordinate: coordinate, radius: radius, language: language)
        if let cached = await cache.places(for: key) { return cached }

        guard let url = requestURL(near: coordinate, radius: radius) else {
            throw PlaceProviderError.noInterestingPlaces
        }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        request.setValue("OneMile/1.0 (iOS; com.friedrichsenweb.OneMile)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw PlaceProviderError.noInterestingPlaces
        }

        let places = try Self.decodePlaces(data, near: coordinate, radius: radius)
        await cache.insert(places, for: key)
        return places
    }

    private func requestURL(near coordinate: Coordinate, radius: CLLocationDistance) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(language).wikipedia.org"
        components.path = "/w/api.php"
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "generator", value: "geosearch"),
            .init(name: "ggscoord", value: "\(coordinate.latitude)|\(coordinate.longitude)"),
            .init(name: "ggsradius", value: "\(min(Int(radius), 10_000))"),
            .init(name: "ggslimit", value: "50"),
            .init(name: "ggsnamespace", value: "0"),
            .init(name: "prop", value: "coordinates|extracts|categories|info"),
            .init(name: "inprop", value: "url"),
            .init(name: "exintro", value: "1"),
            .init(name: "explaintext", value: "1"),
            .init(name: "exsentences", value: "3"),
            .init(name: "cllimit", value: "20"),
            .init(name: "clshow", value: "!hidden"),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2")
        ]
        return components.url
    }

    nonisolated static func decodePlaces(
        _ data: Data, near origin: Coordinate, radius: CLLocationDistance
    ) throws -> [InterestingPlace] {
        let response = try JSONDecoder().decode(WikipediaResponse.self, from: data)
        return (response.query?.pages ?? [])
            .compactMap { page in makePlace(from: page, origin: origin, radius: radius) }
            .sorted { score($0, origin: origin) > score($1, origin: origin) }
    }

    private nonisolated static func makePlace(
        from page: WikipediaPage, origin: Coordinate, radius: CLLocationDistance
    ) -> InterestingPlace? {
        guard let location = page.coordinates?.first,
              let extract = page.extract?.normalizedWhitespace,
              extract.count >= 70 else { return nil }
        let coordinate = Coordinate(latitude: location.lat, longitude: location.lon)
        guard coordinate.distance(to: origin) <= radius * 1.15 else { return nil }

        let categories = page.categories?.map(\.title).joined(separator: " ") ?? ""
        let searchable = "\(page.title) \(categories) \(extract)".lowercased()
        guard !excludedTerms.contains(where: searchable.contains),
              interestingTerms.contains(where: searchable.contains) else { return nil }

        let kind = kind(for: searchable)
        return InterestingPlace(
            id: stableID(for: page.pageid),
            name: page.title,
            coordinate: coordinate,
            kind: kind,
            reason: extract.firstSentence(maxLength: 185),
            detail: String(extract.prefix(650)),
            source: "Wikipedia · CC BY-SA",
            sourceURL: page.fullurl.flatMap(URL.init(string:))
        )
    }

    private nonisolated static func score(_ place: InterestingPlace, origin: Coordinate) -> Double {
        let text = "\(place.name) \(place.detail)".lowercased()
        let signals = interestingTerms.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
        return Double(signals * 100) - place.coordinate.distance(to: origin) / 30
    }

    private nonisolated static func kind(for text: String) -> PlaceKind {
        if text.contains("public art") || text.contains("sculpture") || text.contains("mural") { return .art }
        if text.contains("park") || text.contains("garden") || text.contains("trail") { return .park }
        if text.contains("viewpoint") || text.contains("observation") || text.contains("overlook") { return .viewpoint }
        if text.contains("building") || text.contains("architecture") || text.contains("church") || text.contains("tower") { return .architecture }
        if text.contains("historic") || text.contains("memorial") || text.contains("monument") { return .history }
        return .local
    }

    private nonisolated static func stableID(for pageID: Int) -> UUID {
        let suffix = String(format: "%012llx", Int64(pageID))
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
    }

    private static let interestingTerms = [
        "architecture", "building", "historic", "landmark", "monument", "memorial",
        "museum", "public art", "sculpture", "mural", "park", "garden", "viewpoint",
        "observation", "bridge", "church", "cathedral", "theatre", "theater", "tower",
        "square", "plaza", "station", "library", "trail", "fort", "castle", "district"
    ]

    private static let excludedTerms = [
        "disambiguation", "list of", "people born", "births", "deaths", "living people",
        "electoral district", "sports season", "football season", "album", "television episode"
    ]
}

private struct WikipediaResponse: Decodable {
    let query: WikipediaQuery?
}

private struct WikipediaQuery: Decodable {
    let pages: [WikipediaPage]?
}

private struct WikipediaPage: Decodable {
    let pageid: Int
    let title: String
    let extract: String?
    let fullurl: String?
    let coordinates: [WikipediaCoordinate]?
    let categories: [WikipediaCategory]?
}

private struct WikipediaCoordinate: Decodable {
    let lat: Double
    let lon: Double
}

private struct WikipediaCategory: Decodable {
    let title: String
}

private extension String {
    var normalizedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    func firstSentence(maxLength: Int) -> String {
        let candidates = [". ", "! ", "? "].compactMap { range(of: $0)?.upperBound }
        if let end = candidates.min(), distance(from: startIndex, to: end) <= maxLength {
            return String(self[..<end]).trimmingCharacters(in: .whitespaces)
        }
        guard count > maxLength else { return self }
        return String(prefix(maxLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
