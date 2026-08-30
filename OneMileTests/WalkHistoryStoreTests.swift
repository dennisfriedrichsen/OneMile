import XCTest
@testable import OneMile

@MainActor
final class WalkHistoryStoreTests: XCTestCase {
    func testCompletedWalkPersists() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "one-mile-history-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = WalkPlan(
            id: UUID(), createdAt: .now, startName: "Test", start: .init(latitude: 0, longitude: 0),
            duration: .thirty, stops: [], routeCoordinates: [], distanceMeters: 1_600
        )

        let writer = WalkHistoryStore(url: url)
        writer.add(CompletedWalk(plan: plan))
        let reader = WalkHistoryStore(url: url)

        XCTAssertEqual(reader.walks.count, 1)
        XCTAssertEqual(reader.walks.first?.id, plan.id)
    }
}

