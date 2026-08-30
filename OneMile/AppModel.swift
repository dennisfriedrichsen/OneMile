import Combine
import CoreLocation
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Phase { case planning, preview, walking, completed }

    @Published var phase: Phase = .planning
    @Published var duration: WalkDuration = .sixty
    @Published var selectedStart = Coordinate(latitude: 41.8827, longitude: -87.6233)
    @Published var selectedStartName = "Millennium Park"
    @Published var plan: WalkPlan?
    @Published var selectedStop: InterestingPlace?
    @Published var currentStopIndex = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isUsingFallbackStart = true

    let location: LocationManager
    let search: LocationSearchService
    let history: WalkHistoryStore
    private let generator: RouteGenerator

    static func live() -> AppModel {
        AppModel(
            generator: RouteGenerator(provider: CompositePlaceProvider(), routeBuilder: MapKitWalkingRouteBuilder()),
            location: LocationManager(), search: LocationSearchService(), history: WalkHistoryStore()
        )
    }

    init(generator: RouteGenerator, location: LocationManager, search: LocationSearchService, history: WalkHistoryStore) {
        self.generator = generator
        self.location = location
        self.search = search
        self.history = history
    }

    func useCurrentLocation() {
        isUsingFallbackStart = false
        location.requestLocation()
        if let coordinate = location.coordinate { applyCurrentLocation(coordinate) }
    }

    func applyCurrentLocation(_ coordinate: Coordinate) {
        guard !isUsingFallbackStart else { return }
        selectedStart = coordinate
        selectedStartName = "Current Location"
    }

    func selectSearchResult(_ result: SearchResult) {
        Task {
            do {
                let (coordinate, name) = try await search.resolve(result)
                selectedStart = coordinate
                selectedStartName = name
                isUsingFallbackStart = true
            } catch {
                errorMessage = "That place couldn't be loaded. Try another search result."
            }
        }
    }

    func selectDroppedPin(_ coordinate: Coordinate) {
        selectedStart = coordinate
        selectedStartName = "Dropped Pin"
        isUsingFallbackStart = true
    }

    func generateWalk() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                plan = try await generator.generate(from: selectedStart, name: selectedStartName, duration: duration)
                phase = .preview
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "We couldn't build this walk. Please try again."
            }
            isLoading = false
        }
    }

    func beginWalk() {
        currentStopIndex = 0
        phase = .walking
        location.startWalkingUpdates()
    }

    func markCurrentStopVisited() {
        guard let plan else { return }
        if currentStopIndex + 1 < plan.stops.count {
            currentStopIndex += 1
        } else {
            finishWalk()
        }
    }

    func updateProgress(for coordinate: Coordinate) {
        guard phase == .walking, let nextStop else { return }
        if coordinate.distance(to: nextStop.coordinate) < 45 { markCurrentStopVisited() }
    }

    func finishWalk() {
        guard let plan else { return }
        history.add(CompletedWalk(plan: plan))
        location.stopWalkingUpdates()
        phase = .completed
    }

    func reset() {
        plan = nil
        selectedStop = nil
        currentStopIndex = 0
        phase = .planning
    }

    var nextStop: InterestingPlace? {
        guard let plan, plan.stops.indices.contains(currentStopIndex) else { return nil }
        return plan.stops[currentStopIndex]
    }

    var distanceToNextStop: CLLocationDistance? {
        guard let current = location.coordinate, let nextStop else { return nil }
        return current.distance(to: nextStop.coordinate)
    }
}

