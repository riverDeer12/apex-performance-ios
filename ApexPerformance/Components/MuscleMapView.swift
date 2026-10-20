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

/// How a workout works a muscle.
enum MuscleRole {
    /// Does most of the work.
    case primary
    /// Helps.
    case secondary
}

/// Front and back of a body with the muscles a workout works highlighted:
/// primary ones in the app's main color, secondary ones lighter.
struct MuscleMapView: View {
    let primary: [String]
    var secondary: [String] = []

    private static let silhouette = BodyMapPaths.silhouette.map(SVGPath.parse)
    private static let details = BodyMapPaths.details.map(SVGPath.parse)
    private static let shapes = BodyMapPaths.muscles.map { (code: $0.code, paths: $0.paths.map(SVGPath.parse)) }

    static let secondaryOpacity = 0.4

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / BodyMapPaths.size.width, size.height / BodyMapPaths.size.height)
            let offsetX = (size.width - BodyMapPaths.size.width * scale) / 2
            context.translateBy(x: offsetX, y: 0)
            context.scaleBy(x: scale, y: scale)

            let outline = Self.silhouette.reduce(into: Path()) { $0.addPath($1) }
            let line = StrokeStyle(lineWidth: 0.3, lineJoin: .round)

            context.fill(outline, with: .color(Color.primary.opacity(0.08)))

            // Muscles reach over the body's edge, the outline cuts them.
            var muscles = context
            muscles.clip(to: outline)
            for path in Self.details {
                muscles.fill(path, with: .color(Color.primary.opacity(0.13)))
                muscles.stroke(path, with: .color(Color.primary.opacity(0.25)), style: line)
            }
            for shape in Self.shapes {
                let fill: Color = if primary.contains(shape.code) {
                    Color.apexMainColor
                } else if secondary.contains(shape.code) {
                    Color.apexMainColor.opacity(Self.secondaryOpacity)
                } else {
                    Color.primary.opacity(0.17)
                }
                for path in shape.paths {
                    muscles.fill(path, with: .color(fill))
                    muscles.stroke(path, with: .color(Color.primary.opacity(0.3)), style: line)
                }
            }

            context.stroke(outline, with: .color(Color.primary.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 0.5, lineJoin: .round))
        }
        .aspectRatio(BodyMapPaths.size.width / BodyMapPaths.size.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("worked_muscles"))
    }
}

/// Primary and secondary muscles by name, with the colors of the body map.
struct MuscleLegendView: View {
    let primary: [String]
    let secondary: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !primary.isEmpty {
                row(title: "primary_muscles", muscles: primary, color: Color.apexMainColor)
            }
            if !secondary.isEmpty {
                row(title: "secondary_muscles", muscles: secondary,
                    color: Color.apexMainColor.opacity(MuscleMapView.secondaryOpacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(title: LocalizedStringKey, muscles: [String], color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(muscles.map { String(localized: String.LocalizationValue("muscle_" + $0)) }
                    .joined(separator: " · "))
                    .font(.subheadline)
            }
        }
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
