import CoreLocation
import Foundation

enum WalkFormatting {
    static func distance(_ meters: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = meters > 1_000 ? 1 : 0
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}

