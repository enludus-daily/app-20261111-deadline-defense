import SwiftUI

/// 3 ページのオンボーディング。動く見本で「締め切りが歩いてくる → 済ませたら砲台が撃つ → 大きい敵は分ける」を見せる。
/// ページ送りは自前（TabView(.page) は撮影で黒い丸が出るため使わない）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < 2 {
                    Button("とばす") { finish() }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            Spacer(minLength: 8)

            OnboardingScene(page: page, reduceMotion: reduceMotion)
                .frame(maxWidth: 360)
                .frame(height: 300)
                .padding(.horizontal, 24)
                .id(page)
                .transition(.opacity)

            VStack(spacing: 10) {
                Text(title)
                    .font(Theme.serif(26, .regular))
                    .kerning(-0.6)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .id("text-\(page)")
            .transition(.opacity)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Theme.skyDeep : Theme.line).frame(width: i == page ? 18 : 6, height: 6)
                }
            }
            .padding(.bottom, 18)

            Button {
                model.select()
                if page < 2 {
                    withAnimation(.easeOut(duration: 0.3)) { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < 2 ? LocalizedStringKey("次へ") : LocalizedStringKey("城を守りはじめる"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 360, minHeight: 52)
                    .background(Capsule().fill(Theme.skyDeep))
            }
            .buttonStyle(PressStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .accessibilityIdentifier("main.onboardingNext")
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    private var title: LocalizedStringKey {
        switch page {
        case 0: return "締め切りが、歩いてくる"
        case 1: return "済ませたら、砲台が撃つ"
        default: return "大きい敵は、分けて倒す"
        }
    }

    private var detail: LocalizedStringKey {
        switch page {
        case 0: return "用事を1行で入れると、敵になって城（今日のあなた）へ向かいます。城に近いほど、締め切りが近い。"
        case 1: return "本当に済ませた瞬間に◎を押すと、砲台が撃って敵が消えます。続けて倒すと連続になります。"
        default: return "重い敵は長押しで小さく分けると、1回で倒れます。データはこの iPhone の中だけに残ります。"
        }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.35)) { model.onboarded = true }
    }
}

/// 動く見本（表示中だけ 1 回動く。くり返しの無限の動きは使わない）
struct OnboardingScene: View {
    let page: Int
    let reduceMotion: Bool
    @State private var phase: CGFloat = 0
    @State private var popped = false

    var body: some View {
        GeometryReader { proxy in
            let path = MarchPath(size: proxy.size, samples: 80)
            ZStack {
                MapTheme.meadow.ground
                Canvas { context, _ in
                    var line = Path()
                    line.addLines(path.points)
                    context.stroke(line, with: .color(MapTheme.meadow.road), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                    context.stroke(line, with: .color(Theme.card), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 7]))
                }
                CastleFigure(health: 10, level: 3)
                    .position(x: proxy.size.width * MarchPath.castleSpot.x, y: proxy.size.height * MarchPath.castleSpot.y - 6)
                switch page {
                case 0:
                    ForEach(0..<3, id: \.self) { i in
                        let t = min(0.95, Double(i) * 0.25 + 0.1 + Double(phase) * 0.35)
                        FoeFigure(weight: [3, 2, 1][i], stage: t > 0.85 ? .gate : (t > 0.4 ? .near : .far), progress: t)
                            .position(path.point(at: t))
                    }
                case 1:
                    TowerFigure(kind: .basic, firing: phase > 0.5)
                        .position(x: proxy.size.width * 0.66, y: proxy.size.height * 0.54)
                    let target = path.point(at: 0.6)
                    FoeFigure(weight: 2, stage: .near, progress: 0.6)
                        .scaleEffect(popped ? 0.01 : 1)
                        .opacity(popped ? 0 : 1)
                        .position(target)
                    Circle().stroke(Theme.sky, lineWidth: 2).frame(width: 30, height: 30)
                        .scaleEffect(popped ? 2 : 0.4)
                        .opacity(popped ? 0 : (phase > 0.5 ? 1 : 0))
                        .position(target)
                    if phase > 0 && phase < 1 {
                        Circle().fill(Theme.skyDeep).frame(width: 7, height: 7)
                            .position(x: proxy.size.width * 0.66 + (target.x - proxy.size.width * 0.66) * phase,
                                      y: proxy.size.height * 0.54 - 10 + (target.y - proxy.size.height * 0.54 + 10) * phase)
                    }
                default:
                    let big = path.point(at: 0.45)
                    FoeFigure(weight: 3, stage: .near, progress: 0.45)
                        .opacity(Double(1 - phase))
                        .scaleEffect(1 - phase * 0.3)
                        .position(big)
                    ForEach(0..<3, id: \.self) { i in
                        let t = 0.38 + Double(i) * 0.07
                        FoeFigure(weight: 1, stage: .near, progress: t)
                            .opacity(Double(phase))
                            .position(path.point(at: t, lane: i, spacing: 10))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                phase = 1
                popped = page == 1
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeInOut(duration: page == 1 ? 0.5 : 1.4)) { phase = 1 }
            if page == 1 {
                try? await Task.sleep(for: .milliseconds(520))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { popped = true }
            }
        }
    }
}
