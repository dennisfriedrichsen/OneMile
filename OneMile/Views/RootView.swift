import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .planning: PlanningView()
                case .preview: RoutePreviewView()
                case .walking: WalkingView()
                case .completed: CompletionView()
                }
            }
            .animation(.snappy, value: phaseKey)
        }
        .sheet(item: $model.selectedStop) { StopDetailView(stop: $0) }
        .alert("Couldn't Make a Walk", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
        .onChange(of: model.location.coordinate) { _, coordinate in
            guard let coordinate else { return }
            model.applyCurrentLocation(coordinate)
            model.updateProgress(for: coordinate)
        }
    }

    private var phaseKey: String { String(describing: model.phase) }
    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

