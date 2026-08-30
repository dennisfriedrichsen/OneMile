import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72)).foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Walk complete").font(.largeTitle.bold())
                Text("You saw \(model.plan?.stops.count ?? 0) places that were worth the detour.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            if let plan = model.plan {
                HStack(spacing: 28) {
                    metric("Time", "\(plan.estimatedMinutes) min")
                    metric("Distance", WalkFormatting.distance(plan.distanceMeters))
                    metric("Stops", "\(plan.stops.count)")
                }
                .padding(.vertical)
            }
            Spacer()
            Button("Make Another Walk", action: model.reset)
                .frame(maxWidth: .infinity).buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(24)
        .navigationBarBackButtonHidden()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
