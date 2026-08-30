import SwiftUI

@main
struct OneMileApp: App {
    @StateObject private var model = AppModel.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(.accentColor)
        }
    }
}

