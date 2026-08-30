import MapKit
import SwiftUI

struct StopDetailView: View {
    let stop: InterestingPlace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: stop.coordinate.clLocation, latitudinalMeters: 450, longitudinalMeters: 450
                    ))) {
                        Marker(stop.name, systemImage: stop.kind.symbol, coordinate: stop.coordinate.clLocation)
                            .tint(Color.accentColor)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Label(stop.kind.rawValue.capitalized, systemImage: stop.kind.symbol)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(stop.reason).font(.title2.weight(.semibold))
                    Text(stop.detail).font(.body).lineSpacing(4)
                    Divider()
                    HStack {
                        Text("Source: \(stop.source)")
                        Spacer()
                        if let sourceURL = stop.sourceURL {
                            Link("View source", destination: sourceURL)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(stop.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
