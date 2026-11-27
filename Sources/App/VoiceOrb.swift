import SwiftUI

struct VoiceOrb: View {
    let level: Float
    let output: Float
    let active: Bool
    let playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || (!active && !playing))) { timeline in
            Canvas { context, size in
                let time = reduceMotion || (!active && !playing) ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let strength = Double(playing ? output : (active ? level : 0))
                let side = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let shell = blob(center: center, radius: side * 0.39, time: time, strength: strength)
                var glow = context
                glow.addFilter(.blur(radius: side * 0.08))
                glow.opacity = 0.28 + strength * 0.25
                glow.fill(blob(center: center, radius: side * 0.43, time: time, strength: strength),
                          with: .color(playing ? VoiceTheme.sky : VoiceTheme.lilac))
                context.fill(shell, with: .linearGradient(Gradient(colors: [VoiceTheme.rose, VoiceTheme.lilac, VoiceTheme.sky]),
                    startPoint: CGPoint(x: 0, y: side), endPoint: CGPoint(x: side, y: 0)))
                var liquid = context
                liquid.clip(to: shell)
                liquid.addFilter(.blur(radius: side * 0.09))
                let colors = playing ? [VoiceTheme.sky, VoiceTheme.mint, VoiceTheme.lilac] : [VoiceTheme.lilac, VoiceTheme.rose, VoiceTheme.sky]
                for index in 0..<3 {
                    let phase = time * (playing ? 0.9 : 0.5) + Double(index) * 2.1
                    let point = CGPoint(x: center.x + cos(phase) * side * 0.21,
                                        y: center.y + sin(phase * 1.2) * side * 0.22)
                    let diameter = side * (0.64 + strength * 0.15)
                    liquid.fill(Path(ellipseIn: CGRect(x: point.x - diameter/2, y: point.y - diameter/2,
                                                      width: diameter, height: diameter)), with: .color(colors[index]))
                }
                context.stroke(shell, with: .color(.white.opacity(0.38)), lineWidth: side * 0.004)
                if active || playing {
                    context.stroke(blob(center: center, radius: side * 0.45, time: time + 1, strength: strength),
                        with: .color((playing ? VoiceTheme.accent : VoiceTheme.lilac).opacity(0.2 + strength * 0.3)),
                        lineWidth: side * 0.006)
                }
            }
        }.accessibilityIdentifier("voiceOrb")
    }
    private func blob(center: CGPoint, radius: CGFloat, time: Double, strength: Double) -> Path {
        var path = Path()
        for index in 0..<128 {
            let angle = Double(index) / 128 * .pi * 2
            let movement = sin(angle * 3 + time * 1.5) * 0.025 + cos(angle * 5 - time * 1.1) * 0.016
            let wave = sin(angle * 7 + time * 4) * strength * 0.04
            let r = radius * (1 + CGFloat(movement + wave + strength * 0.12))
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
