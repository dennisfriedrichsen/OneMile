import SwiftUI

struct RoutePreviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let plan = model.plan {
            VStack(spacing: 0) {
                RouteMapView(plan: plan, activeStopIndex: nil)
                    .frame(height: 310)
                    .overlay(alignment: .bottomLeading) {
                        routeSummary(plan).padding(12)
                    }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, stop in
                            StopRow(number: index + 1, stop: stop) { model.selectedStop = stop }
                            if index < plan.stops.count - 1 { Divider().padding(.leading, 60) }
                        }
                    }
                }

                Button("Start Walking", systemImage: "figure.walk", action: model.beginWalk)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .padding()
                    .background(.bar)
            }
            .navigationTitle("Your Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") { model.reset() }
                }
            }
        }
    }

    private func routeSummary(_ plan: WalkPlan) -> some View {
        HStack(spacing: 12) {
            Label("\(plan.estimatedMinutes) min", systemImage: "clock")
            Label(WalkFormatting.distance(plan.distanceMeters), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            Label("\(plan.stops.count) stops", systemImage: "mappin.and.ellipse")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StopRow: View {
    let number: Int
    let stop: InterestingPlace
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(Color.accentColor)
                    Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
                }.frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(stop.name).font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: stop.kind.symbol).foregroundStyle(.secondary)
                    }
                    Text(stop.reason).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary).padding(.top, 6)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

