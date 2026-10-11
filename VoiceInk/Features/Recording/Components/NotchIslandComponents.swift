import SwiftUI

enum NotchIslandPalette {
    static let recording = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let primary = Color.white.opacity(0.92)
    static let secondary = Color.white.opacity(0.45)
}

struct NotchIslandRecordingDot: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(NotchIslandPalette.recording.opacity(0.45))
                .scaleEffect(isPulsing ? 1.9 : 1.0)
                .opacity(isPulsing ? 0 : 1)
            Circle()
                .fill(NotchIslandPalette.recording)
                .shadow(color: NotchIslandPalette.recording.opacity(0.7), radius: 3)
        }
        .frame(width: 8, height: 8)
        .onAppear {
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

struct NotchIslandElapsedTime: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(startedAt)))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(NotchIslandPalette.primary)
                .contentTransition(.numericText())
        }
    }
}

struct NotchIslandWaveform: View {
    let levelProvider: () -> Double
    let isActive: Bool
    let maxBarHeight: CGFloat

    private let weights: [Double] = [0.5, 0.78, 1.0, 0.78, 0.5]
    private let barWidth: CGFloat = 3
    private let minBarHeight: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isActive)) { context in
            let level = isActive ? max(0, min(1, pow(levelProvider(), 0.6))) : 0
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(weights.indices, id: \.self) { index in
                    let wobble = 0.65 + 0.35 * sin(time * 9 + Double(index) * 1.3)
                    let height = minBarHeight + CGFloat(level * weights[index] * wobble) * (maxBarHeight - minBarHeight)
                    Capsule()
                        .fill(isActive ? NotchIslandPalette.primary : NotchIslandPalette.secondary)
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(height: maxBarHeight)
            .animation(.interpolatingSpring(stiffness: 260, damping: 18), value: level)
        }
    }
}

struct NotchIslandProcessingIndicator: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3.5) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = (sin(time * 5 - Double(index) * 0.9) + 1) / 2
                    Circle()
                        .fill(NotchIslandPalette.primary.opacity(0.35 + 0.65 * wave))
                        .frame(width: 4.5, height: 4.5)
                        .offset(y: -2.5 * wave)
                }
            }
        }
    }
}

struct NotchIslandSpinner: View {
    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0.12, to: 0.82)
            .stroke(NotchIslandPalette.primary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            .frame(width: 11, height: 11)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    isRotating = true
                }
            }
    }
}
