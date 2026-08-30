import Foundation

struct CacheKey: Codable, Hashable, Sendable {
    let latitudeCell: Int
    let longitudeCell: Int
    let radiusBucket: Int
    let language: String

    init(coordinate: Coordinate, radius: Double, language: String) {
        latitudeCell = Int((coordinate.latitude * 100).rounded())
        longitudeCell = Int((coordinate.longitude * 100).rounded())
        radiusBucket = Int((radius / 500).rounded(.up))
        self.language = language
    }
}

actor WikipediaPlaceCache {
    private struct Entry: Codable {
        let key: CacheKey
        let savedAt: Date
        let places: [InterestingPlace]
    }

    private let url: URL
    private var entries: [Entry]
    private let lifetime: TimeInterval = 30 * 24 * 60 * 60
    private let maximumEntries = 30

    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    func places(for key: CacheKey, now: Date = .now) -> [InterestingPlace]? {
        entries.removeAll { now.timeIntervalSince($0.savedAt) > lifetime }
        return entries.first(where: { $0.key == key })?.places
    }

    func insert(_ places: [InterestingPlace], for key: CacheKey, now: Date = .now) {
        entries.removeAll { $0.key == key || now.timeIntervalSince($0.savedAt) > lifetime }
        entries.insert(Entry(key: key, savedAt: now, places: places), at: 0)
        entries = Array(entries.prefix(maximumEntries))
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

