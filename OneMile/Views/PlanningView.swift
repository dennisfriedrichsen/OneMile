import MapKit
import SwiftUI

struct PlanningView: View {
    @EnvironmentObject private var model: AppModel
    @State private var camera: MapCameraPosition = .automatic
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            startMap
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) { searchArea.padding() }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("STARTING NEAR").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(model.selectedStartName).font(.headline).lineLimit(1)
                    }
                    Spacer()
                    Button("Use My Location", systemImage: "location.fill") { model.useCurrentLocation() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Use my current location")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("How much time do you have?").font(.headline)
                    Picker("Walk duration", selection: $model.duration) {
                        ForEach(WalkDuration.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Button(action: model.generateWalk) {
                    HStack {
                        if model.isLoading { ProgressView().tint(.white) }
                        Text(model.isLoading ? "Finding the good stuff…" : "Make My Walk")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isLoading)
            }
            .padding(20)
            .background(.background)
        }
        .navigationTitle("One Mile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            camera = .region(MKCoordinateRegion(center: model.selectedStart.clLocation, latitudinalMeters: 1_800, longitudinalMeters: 1_800))
            if model.isUsingFallbackStart { model.useCurrentLocation() }
        }
        .onChange(of: model.selectedStart) { _, value in
            camera = .region(MKCoordinateRegion(center: value.clLocation, latitudinalMeters: 1_800, longitudinalMeters: 1_800))
        }
    }

    private var startMap: some View {
        MapReader { proxy in
            Map(position: $camera) {
                Marker(model.selectedStartName, coordinate: model.selectedStart.clLocation)
                    .tint(Color.accentColor)
                UserAnnotation()
            }
            .mapControls { MapCompass(); MapScaleView() }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    model.selectDroppedPin(Coordinate(coordinate))
                    searchFocused = false
                }
            }
            .accessibilityLabel("Map of the selected starting area. Double tap to drop a pin.")
        }
    }

    private var searchArea: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search for a starting place", text: Binding(
                    get: { model.search.query },
                    set: { model.search.query = $0 }
                ))
                    .focused($searchFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                if !model.search.query.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") { model.search.query = "" }
                        .labelStyle(.iconOnly).foregroundStyle(.secondary)
                }
            }
            .padding(12)

            if searchFocused && !model.search.results.isEmpty {
                Divider()
                ForEach(model.search.results.prefix(5)) { result in
                    Button {
                        model.selectSearchResult(result)
                        searchFocused = false
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title).foregroundStyle(.primary).lineLimit(1)
                            Text(result.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                    }
                    if result.id != model.search.results.prefix(5).last?.id { Divider().padding(.leading, 12) }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }
}
