import XCTest
@testable import OneMile

final class WikipediaPlaceProviderTests: XCTestCase {
    func testEmptyResponseProducesEmptyResult() throws {
        let origin = Coordinate(latitude: 41.88, longitude: -87.63)
        let places = try WikipediaPlaceProvider.decodePlaces(
            Data(#"{"batchcomplete":true,"query":{}}"#.utf8), near: origin, radius: 2_000
        )
        XCTAssertTrue(places.isEmpty)
    }

    func testDecodingKeepsInterestingPlacesAndRejectsBiographies() throws {
        let json = #"""
        {
          "query": {
            "pages": [
              {
                "pageid": 101,
                "title": "Old Water Tower",
                "extract": "The Old Water Tower is a historic limestone building completed in 1869. It survived a major city fire and remains a local landmark.",
                "fullurl": "https://en.wikipedia.org/wiki/Old_Water_Tower",
                "coordinates": [{"lat": 41.881, "lon": -87.631}],
                "categories": [{"title": "Category:Historic buildings"}]
              },
              {
                "pageid": 102,
                "title": "Jane Example",
                "extract": "Jane Example was an architect and writer whose long career included several important projects in the region.",
                "fullurl": "https://en.wikipedia.org/wiki/Jane_Example",
                "coordinates": [{"lat": 41.882, "lon": -87.632}],
                "categories": [{"title": "Category:Living people"}]
              }
            ]
          }
        }
        """#
        let origin = Coordinate(latitude: 41.88, longitude: -87.63)

        let places = try WikipediaPlaceProvider.decodePlaces(Data(json.utf8), near: origin, radius: 2_000)

        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.name, "Old Water Tower")
        XCTAssertEqual(places.first?.kind, .architecture)
        XCTAssertEqual(places.first?.source, "Wikipedia · CC BY-SA")
        XCTAssertEqual(places.first?.sourceURL?.host(), "en.wikipedia.org")
        XCTAssertEqual(places.first?.reason, "The Old Water Tower is a historic limestone building completed in 1869.")
    }

    func testCacheReturnsSavedPlacesAndExpiresOldEntries() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "wikipedia-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = WikipediaPlaceCache(url: url)
        let key = CacheKey(coordinate: .init(latitude: 41.88, longitude: -87.63), radius: 2_000, language: "en")
        let place = InterestingPlace(
            name: "Test Building", coordinate: .init(latitude: 41.88, longitude: -87.63),
            kind: .architecture, reason: "Worth seeing.", detail: "A historic building.", source: "Test"
        )
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        await cache.insert([place], for: key, now: now)
        let current = await cache.places(for: key, now: now.addingTimeInterval(60))
        let expired = await cache.places(for: key, now: now.addingTimeInterval(31 * 24 * 60 * 60))

        XCTAssertEqual(current?.first?.name, "Test Building")
        XCTAssertNil(expired)
    }
}
