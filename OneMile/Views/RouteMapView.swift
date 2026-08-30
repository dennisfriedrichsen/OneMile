import MapKit
import SwiftUI

struct RouteMapView: View {
    let plan: WalkPlan
    var activeStopIndex: Int?
    var showsUserLocation = false
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $camera) {
            if plan.routeCoordinates.count > 1 {
                MapPolyline(coordinates: plan.routeCoordinates.map(\.clLocation))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            Annotation("Start", coordinate: plan.start.clLocation) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.title).foregroundStyle(.white, Color.accentColor)
                    .accessibilityLabel("Walk start")
            }
            ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, stop in
                Annotation(stop.name, coordinate: stop.coordinate.clLocation) {
                    ZStack {
                        Circle().fill(index == activeStopIndex ? Color.orange : Color.accentColor)
                        Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white)
                    }
                    .frame(width: index == activeStopIndex ? 34 : 28, height: index == activeStopIndex ? 34 : 28)
                    .shadow(radius: 2, y: 1)
                    .accessibilityLabel("Stop \(index + 1), \(stop.name)")
                }
            }
            if showsUserLocation { UserAnnotation() }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapCompass(); MapScaleView(); if showsUserLocation { MapUserLocationButton() } }
    }
}
