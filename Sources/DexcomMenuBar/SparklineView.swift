import SwiftUI

public struct SparklineView: View {
    public let readings: [GlucoseReading]
    public let unit: GlucoseUnit
    public let isDemo: Bool

    // Target range in mg/dL
    private let targetLow: Double = 70.0
    private let targetHigh: Double = 180.0

    @State private var hoveredReading: GlucoseReading? = nil
    @State private var hoverLocationX: CGFloat? = nil

    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()

    public init(readings: [GlucoseReading], unit: GlucoseUnit, isDemo: Bool = false) {
        // Chronological order for drawing left-to-right (oldest -> newest)
        self.readings = readings.reversed()
        self.unit = unit
        self.isDemo = isDemo
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header showing live target range or Apple Health-style inspection details
            HStack(alignment: .firstTextBaseline) {
                if let selected = hoveredReading {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selected.category.color)
                            .frame(width: 7, height: 7)

                        Text(selected.formattedValue(unit: unit) + " " + unit.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        Text(selected.trend.symbol)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(selected.category.color)

                        Text("• " + timeFormatter.string(from: selected.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                } else {
                    Text("Trend History (\(readings.count) points)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Target: \(unit.format(mgdL: targetLow)) - \(unit.format(mgdL: targetHigh))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                if readings.count >= 2 {
                    let minVal = min(targetLow - 15, readings.map { $0.value }.min() ?? targetLow)
                    let maxVal = max(targetHigh + 20, readings.map { $0.value }.max() ?? targetHigh)
                    let valRange = max(1, maxVal - minVal)

                    let yHigh = height * (1 - CGFloat((targetHigh - minVal) / valRange))
                    let yLow = height * (1 - CGFloat((targetLow - minVal) / valRange))

                    ZStack(alignment: .topLeading) {
                        // Liquid target band
                        Path { path in
                            path.addRect(CGRect(x: 0, y: yHigh, width: width, height: max(1, yLow - yHigh)))
                        }
                        .fill(Color.green.opacity(0.08))

                        // Target range guide lines
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: yHigh))
                            path.addLine(to: CGPoint(x: width, y: yHigh))
                            path.move(to: CGPoint(x: 0, y: yLow))
                            path.addLine(to: CGPoint(x: width, y: yLow))
                        }
                        .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                        // Gradient fill under the trend line
                        Path { path in
                            for (index, reading) in readings.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(readings.count - 1)
                                let normalizedY = CGFloat((reading.value - minVal) / valRange)
                                let y = height * (1 - normalizedY)

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.addLine(to: CGPoint(x: 0, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Glucose trend line
                        Path { path in
                            for (index, reading) in readings.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(readings.count - 1)
                                let normalizedY = CGFloat((reading.value - minVal) / valRange)
                                let y = height * (1 - normalizedY)

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                        )

                        // Data point dots
                        ForEach(Array(readings.enumerated()), id: \.offset) { index, reading in
                            let isLatest = (index == readings.count - 1)
                            let isSelected = (hoveredReading?.id == reading.id)
                            let x = width * CGFloat(index) / CGFloat(readings.count - 1)
                            let normalizedY = CGFloat((reading.value - minVal) / valRange)
                            let y = height * (1 - normalizedY)

                            if isLatest && !isSelected {
                                Circle()
                                    .fill(reading.category.color.opacity(0.4))
                                    .frame(width: 14, height: 14)
                                    .position(x: x, y: y)
                            }

                            Circle()
                                .fill(reading.category.color)
                                .frame(width: isSelected ? 8 : (isLatest ? 7 : 3.5), height: isSelected ? 8 : (isLatest ? 7 : 3.5))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: (isLatest || isSelected) ? 1.5 : 0)
                                )
                                .position(x: x, y: y)
                        }

                        // Apple Health style vertical scrubber guide line & cursor dot
                        if let selected = hoveredReading, let hX = hoverLocationX {
                            let normalizedY = CGFloat((selected.value - minVal) / valRange)
                            let selectedY = height * (1 - normalizedY)

                            // Vertical hairline
                            Path { path in
                                path.move(to: CGPoint(x: hX, y: 0))
                                path.addLine(to: CGPoint(x: hX, y: height))
                            }
                            .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))

                            // Luminous highlight pulse at selected point
                            Circle()
                                .fill(selected.category.color.opacity(0.35))
                                .frame(width: 18, height: 18)
                                .position(x: hX, y: selectedY)

                            Circle()
                                .fill(selected.category.color)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .position(x: hX, y: selectedY)

                            // Apple Health hover tooltip badge floating over graph
                            let tooltipWidth: CGFloat = 88
                            let tooltipX: CGFloat = min(max(tooltipWidth / 2 + 4, hX), width - tooltipWidth / 2 - 4)
                            let tooltipY: CGFloat = selectedY < 38 ? selectedY + 28 : selectedY - 24

                            VStack(spacing: 1) {
                                Text("\(selected.formattedValue(unit: unit)) \(unit.rawValue) \(selected.trend.symbol)")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(timeFormatter.string(from: selected.timestamp))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.black.opacity(0.82))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .position(x: tooltipX, y: tooltipY)
                            .allowsHitTesting(false)
                        }
                    }
                    // Interactive Continuous Hover Scrubbing (Apple Health style)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            updateHover(at: location.x, width: width)
                        case .ended:
                            withAnimation(.easeOut(duration: 0.15)) {
                                hoveredReading = nil
                                hoverLocationX = nil
                            }
                        }
                    }
                } else {
                    Text("Collecting continuous glucose readings...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 85)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .overlay {
                if isDemo && hoveredReading == nil {
                    Text("SIMULATION DATA")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color.orange.opacity(0.25))
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func updateHover(at xPos: CGFloat, width: CGFloat) {
        guard readings.count >= 2, width > 0 else { return }
        let clampedX = min(max(0, xPos), width)
        let ratio = clampedX / width
        let index = Int(round(ratio * CGFloat(readings.count - 1)))
        let boundedIndex = min(max(0, index), readings.count - 1)

        let targetReading = readings[boundedIndex]
        let snappedX = width * CGFloat(boundedIndex) / CGFloat(readings.count - 1)

        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.86)) {
            hoveredReading = targetReading
            hoverLocationX = snappedX
        }
    }
}
