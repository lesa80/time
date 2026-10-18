import Foundation
import CoreGraphics

enum WindowGeometry {
    static func savedOrigin(_ values: [Double]?) -> CGPoint? {
        guard let values, values.count == 2, values.allSatisfy(\.isFinite) else { return nil }
        return CGPoint(x: values[0], y: values[1])
    }

    static func fitted(_ requested: CGRect, to screens: [CGRect]) -> CGRect {
        let screens = screens.filter { !$0.isEmpty && !$0.isInfinite && !$0.isNull }
        guard !screens.isEmpty, requested.width > 0, requested.height > 0,
              [requested.minX, requested.minY, requested.width, requested.height].allSatisfy(\.isFinite) else { return requested }
        func overlap(_ screen: CGRect) -> CGFloat {
            let intersection = screen.intersection(requested)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        func distance(_ screen: CGRect) -> CGFloat {
            hypot(screen.midX - requested.midX, screen.midY - requested.midY)
        }
        let screen = screens.sorted {
            let a = overlap($0), b = overlap($1)
            return a == b ? distance($0) < distance($1) : a > b
        }[0]
        let ratio = requested.height / requested.width
        let height = min(requested.height, screen.height, screen.width * ratio)
        let width = min(height / ratio, screen.width)
        return CGRect(x: min(max(requested.minX, screen.minX), screen.maxX - width),
                      y: min(max(requested.minY, screen.minY), screen.maxY - height), width: width, height: height)
    }
}

enum AnimationPolicy {
    static func interval(smooth: Bool, showSeconds: Bool, hasSeconds: Bool, reduceMotion: Bool, lowPower: Bool) -> TimeInterval {
        guard smooth && showSeconds && hasSeconds && !reduceMotion else { return 1 }
        return lowPower ? 1.0 / 15 : 1.0 / 30
    }
}
