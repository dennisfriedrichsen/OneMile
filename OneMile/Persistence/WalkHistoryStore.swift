import Foundation

@MainActor
final class WalkHistoryStore: ObservableObject {
    @Published private(set) var walks: [CompletedWalk] = []
    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? URL.documentsDirectory.appending(path: "completed-walks.json")
        load()
    }

    func add(_ walk: CompletedWalk) {
        guard !walks.contains(where: { $0.id == walk.id }) else { return }
        walks.insert(walk, at: 0)
        walks = Array(walks.prefix(50))
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode([CompletedWalk].self, from: data) else { return }
        walks = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(walks) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

