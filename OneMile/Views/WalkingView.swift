import SwiftUI

struct WalkingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let plan = model.plan, let next = model.nextStop {
            VStack(spacing: 0) {
                RouteMapView(plan: plan, activeStopIndex: model.currentStopIndex, showsUserLocation: true)
                    .frame(height: 330)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("NEXT · STOP \(model.currentStopIndex + 1) OF \(plan.stops.count)")
                                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            Spacer()
                            if let distance = model.distanceToNextStop {
                                Text(WalkFormatting.distance(distance)).font(.headline).foregroundStyle(Color.accentColor)
                            }
                        }
                        Text(next.name).font(.title2.bold())
                        Text(next.reason).font(.body).foregroundStyle(.secondary)
                        Button("Why this stop?", systemImage: "info.circle") { model.selectedStop = next }

                        Divider()
                        Text("What remains").font(.headline)
                        ForEach(Array(plan.stops.enumerated().dropFirst(model.currentStopIndex)), id: \.element.id) { index, stop in
                            HStack(spacing: 12) {
                                Image(systemName: index == model.currentStopIndex ? "location.circle.fill" : "circle")
                                    .foregroundStyle(index == model.currentStopIndex ? Color.accentColor : .secondary)
                                Text(stop.name).lineLimit(1)
                                Spacer()
                                Text("\(index + 1)").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { model.selectedStop = stop }
                        }
                    }
                    .padding(20)
                }

                Button(model.currentStopIndex + 1 == plan.stops.count ? "Finish Walk" : "I've Reached This Stop") {
                    model.markCurrentStopVisited()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .padding()
                .background(.bar)
            }
            .navigationTitle("Walking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("End Walk", role: .destructive) { model.reset() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
    }
}
