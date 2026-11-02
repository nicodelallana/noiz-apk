import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LiveTripWidgetBundle: WidgetBundle {
    var body: some Widget {
        LiveTripActivityWidget()
    }
}

struct LiveTripActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveTripAttributes.self) { context in
            // Lock screen / banner presentation
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(hex: "#0B0D14"))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(context.attributes.lineName)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: context.attributes.lineColorHex))
                            .foregroundColor(.white)
                            .clipShape(Capsule())

                        Text(context.attributes.destination)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.arrivalTime, style: .timer)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#2BB081"))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Scenic horizontal progress track
                        ProgressTrackView(
                            progress: context.state.progress,
                            lineColor: Color(hex: context.attributes.lineColorHex),
                            mode: context.attributes.mode
                        )

                        HStack {
                            Text(context.state.instruction ?? "Próxima parada: \(context.state.nextStop)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#9198AD"))
                                .lineLimit(1)

                            Spacer()

                            Text("\(context.state.stopsRemaining) paradas")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#9198AD"))
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Text(context.attributes.lineName)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: context.attributes.lineColorHex))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            } compactTrailing: {
                Text(context.state.arrivalTime, style: .timer)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#2BB081"))
                    .frame(width: 32)
            } minimal: {
                Image(systemName: context.attributes.mode == "bus" ? "bus.fill" : "tram.fill")
                    .foregroundColor(Color(hex: context.attributes.lineColorHex))
            }
        }
    }
}

// ── Lock Screen Live Activity View ───────────────────────────────────────────
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<LiveTripAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Line Chip + Status Badge
            HStack {
                Text(context.attributes.lineName)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: context.attributes.lineColorHex))
                    .foregroundColor(.white)
                    .clipShape(Capsule())

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }

                Spacer()

                Text("Barik Live")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#9198AD"))
            }

            if context.state.status == "ended" {
                // Success Arrival State
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#2BB081"))
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Has llegado a \(context.attributes.destination)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(context.attributes.lineName) · Viaje completado")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#9198AD"))
                    }
                }
                .padding(.vertical, 6)
            } else {
                // Active In-Progress Metrics
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.arrivalTime, style: .timer)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("min · \(context.state.stopsRemaining) paradas")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#9198AD"))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.instruction ?? "Bájate en \(context.attributes.destination)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if !context.state.nextStop.isEmpty {
                            Text("Próxima: \(context.state.nextStop)")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#9198AD"))
                                .lineLimit(1)
                        }
                    }
                }

                // Scenic Horizontal Progress Track
                ProgressTrackView(
                    progress: context.state.progress,
                    lineColor: Color(hex: context.attributes.lineColorHex),
                    mode: context.attributes.mode
                )

                // Endpoints Row
                HStack {
                    Text(context.attributes.origin)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#9198AD"))
                        .lineLimit(1)
                    Spacer()
                    Text(context.attributes.destination)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#9198AD"))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#151822"))
    }

    private var statusColor: Color {
        if context.state.delaySeconds > 60 {
            return Color(hex: "#FFB84D")
        } else if context.state.isRealtime {
            return Color(hex: "#2BB081")
        } else {
            return Color(hex: "#9198AD")
        }
    }

    private var statusLabel: String {
        if context.state.delaySeconds > 60 {
            return "+\(context.state.delaySeconds / 60) min"
        } else if context.state.isRealtime {
            return "En directo"
        } else {
            return "Según horario"
        }
    }
}

// ── Scenic Progress Track Component ──────────────────────────────────────────
struct ProgressTrackView: View {
    let progress: Double
    let lineColor: Color
    let mode: String

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clampedProgress = min(max(progress, 0.0), 1.0)
            let currentX = width * CGFloat(clampedProgress)

            ZStack(alignment: .leading) {
                // Background Rail
                Capsule()
                    .fill(Color(hex: "#1C202D"))
                    .frame(height: 6)

                // Filled Progress Segment
                Capsule()
                    .fill(lineColor)
                    .frame(width: max(currentX, 6), height: 6)

                // Moving Vehicle Glyph
                Image(systemName: mode == "bus" ? "bus.fill" : "tram.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(lineColor)
                    .clipShape(Circle())
                    .offset(x: max(0, min(currentX - 11, width - 22)))

                // Destination Pin
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .offset(x: width - 8)
            }
        }
        .frame(height: 24)
    }
}

// ── Color Hex Extension ──────────────────────────────────────────────────────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 226, 0, 26)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
