import XCTest
@testable import OneMile

final class RouteGeneratorTests: XCTestCase {
    func testDurationControlsExpectedStopCount() {
        XCTAssertEqual(WalkDuration.thirty.stopCount, 4)
        XCTAssertEqual(WalkDuration.sixty.stopCount, 5)
        XCTAssertEqual(WalkDuration.ninety.stopCount, 7)
    }

    func testLoopSelectionReturnsRequestedUniqueStops() {
        let start = Coordinate(latitude: 41.88, longitude: -87.63)
        let candidates = (0..<10).map { index in
            InterestingPlace(
                name: "Place \(index)",
                coordinate: Coordinate(latitude: 41.88 + Double(index) * 0.001, longitude: -87.63 + Double(10 - index) * 0.001),
                kind: .local, reason: "Interesting", detail: "Details", source: "Test"
            )
        }
        let generator = RouteGenerator(provider: StubProvider(places: candidates), routeBuilder: StubRouteBuilder())
        let result = generator.selectLoop(from: start, candidates: candidates, count: 5)

        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(Set(result.map(\.id)).count, 5)
    }

    func testGeneratedPlanIncludesReturnToStart() async throws {
        let start = Coordinate(latitude: 41.88, longitude: -87.63)
        let candidates = (0..<7).map { index in
            InterestingPlace(
                name: "Place \(index)",
                coordinate: Coordinate(latitude: 41.881 + Double(index) * 0.001, longitude: -87.629 + Double(index % 2) * 0.001),
                kind: .history, reason: "Interesting", detail: "Details", source: "Test"
            )
        }
        let generator = RouteGenerator(provider: StubProvider(places: candidates), routeBuilder: StubRouteBuilder())
        let plan = try await generator.generate(from: start, name: "Test Start", duration: .thirty)

        XCTAssertEqual(plan.stops.count, 4)
        XCTAssertEqual(plan.routeCoordinates.first, start)
        XCTAssertEqual(plan.routeCoordinates.last, start)
        XCTAssertGreaterThan(plan.distanceMeters, 0)
    }
}

private struct StubProvider: InterestingPlaceProviding {
    let places: [InterestingPlace]
    func places(near coordinate: Coordinate, radius: Double) async throws -> [InterestingPlace] { places }
}

private struct StubRouteBuilder: WalkingRouteBuilding {
    func route(from start: Coordinate, through stops: [InterestingPlace]) async -> ([Coordinate], Double) {
        let coordinates = [start] + stops.map(\.coordinate) + [start]
        let distance = zip(coordinates, coordinates.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
        return (coordinates, distance)
    }
}

