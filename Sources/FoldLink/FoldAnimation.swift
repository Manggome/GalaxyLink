import SwiftUI

struct FoldAnimation: View {
    let frame: FrameSize?
    let transitions: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var demoExpanded = false
    private let mint = Color(red: 0.45, green: 0.91, blue: 0.75)
    private var expanded: Bool { frame?.expanded ?? demoExpanded }
    private var landscape: Bool { frame.map { $0.width > $0.height } ?? false }
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Ellipse().fill(mint.opacity(expanded ? 0.2 : 0.08))
                    .frame(width: expanded ? 200 : 100, height: 100).blur(radius: 24)
                HStack(spacing: 2) {
                    panel.overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.7)).frame(width: 13, height: 3).padding(.top, 8)
                    }
                    panel
                        .overlay(LinearGradient(colors: [.black.opacity(expanded ? 0 : 0.5), .clear], startPoint: .leading, endPoint: .trailing))
                        .rotation3DEffect(.degrees(expanded ? 0 : -88), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.35)
                        .frame(width: expanded ? 80 : 0).opacity(expanded ? 1 : 0)
                }
                .frame(width: expanded ? 162 : 80, height: 166)
                .rotationEffect(.degrees(landscape && !expanded ? 90 : 0))
                .shadow(color: mint.opacity(0.3), radius: expanded ? 22 : 10)
            }.frame(width: 210, height: 205)
            .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8), value: expanded)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85), value: landscape)
            Text(frame == nil ? "접힘 ↔ 펼침 미리보기" : (expanded ? "넓은 화면 · 자동 전환" : "커버 비율 · 자동 전환"))
                .font(.caption).foregroundStyle(mint)
            if frame == nil {
                Button("애니메이션 미리보기") { demoExpanded.toggle() }.font(.caption)
            } else {
                Text("화면 비율 전환 \(transitions)회").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    private var panel: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(colors: [mint.opacity(0.9), Color.cyan.opacity(0.35), Color.indigo.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
            .frame(width: 80)
    }
}
