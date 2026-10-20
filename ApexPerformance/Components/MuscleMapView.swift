//
//  MuscleMapView.swift
//  ApexPerformance
//

import SwiftUI

/// Muscles a workout works, as the API returns their codes.
enum WorkoutMuscle {
    /// Codes in the order they are listed.
    static let all = BodyMapPaths.muscles.map(\.code)

    static func name(_ code: String) -> LocalizedStringKey {
        LocalizedStringKey("muscle_\(code)")
    }
}

/// Front and back of a body with the given muscles highlighted in the
/// app's main color.
struct MuscleMapView: View {
    let muscles: [String]

    private static let silhouette = BodyMapPaths.silhouette.map(SVGPath.parse)
    private static let shapes = BodyMapPaths.muscles.map { (code: $0.code, paths: $0.paths.map(SVGPath.parse)) }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / BodyMapPaths.size.width, size.height / BodyMapPaths.size.height)
            let offsetX = (size.width - BodyMapPaths.size.width * scale) / 2
            context.translateBy(x: offsetX, y: 0)
            context.scaleBy(x: scale, y: scale)

            for path in Self.silhouette {
                context.fill(path, with: .color(Color.primary.opacity(0.08)))
            }
            for shape in Self.shapes {
                let isWorked = muscles.contains(shape.code)
                for path in shape.paths {
                    context.fill(path, with: .color(isWorked ? Color.apexMainColor : Color.primary.opacity(0.14)))
                }
            }
        }
        .aspectRatio(BodyMapPaths.size.width / BodyMapPaths.size.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("worked_muscles"))
    }
}

/// Parses the SVG path data of the body map (absolute M, L, C and Z only).
enum SVGPath {
    static func parse(_ data: String) -> Path {
        var path = Path()
        let tokens = data.split(separator: " ")
        var index = 0
        var command: Substring = "M"

        func number() -> CGFloat {
            defer { index += 1 }
            return CGFloat(Double(tokens[index]) ?? 0)
        }

        func point() -> CGPoint {
            CGPoint(x: number(), y: number())
        }

        while index < tokens.count {
            let token = tokens[index]
            if Double(token) == nil {
                command = token
                index += 1
                if command == "Z" {
                    path.closeSubpath()
                    continue
                }
            }
            switch command {
            case "M": path.move(to: point())
            case "L": path.addLine(to: point())
            case "C":
                let control1 = point()
                let control2 = point()
                path.addCurve(to: point(), control1: control1, control2: control2)
            default: index += 1
            }
        }
        return path
    }
}
