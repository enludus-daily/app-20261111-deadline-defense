import SwiftUI

/// 戦場の地図：道・敵・城・砲台。文字を読まずに「何が近いか」が分かることを目標にする
struct MapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var focusID: UUID?
    var onTapFoe: (Foe) -> Void = { _ in }
    var onLongPressFoe: (Foe) -> Void = { _ in }
    /// 撮影用：弾が飛んでいる途中で止める（-screenshotScene shot）
    var freezeShots: Bool { Launch.scene == "shot" }

    @State private var shots: [ShotAnim] = []
    @State private var castleShake: CGFloat = 0
    @State private var firingTower: Int?
    @State private var spawnedID: UUID?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let path = MarchPath(size: size)
            let theme = model.effectiveTheme
            let level = model.chronicle.castleLevel
            let towers = path.towerPoints(count: min(MarchPath.towerProgress.count, 2 + level / 2))
            ZStack {
                ground(theme: theme, size: size)
                road(path: path, theme: theme)
                milestones(path: path)
                entrance(at: path.point(at: 0))

                ForEach(Array(towers.enumerated()), id: \.offset) { index, spot in
                    TowerFigure(kind: model.effectiveTower, firing: firingTower == index)
                        .position(spot)
                }

                CastleFigure(health: model.castleHealth, level: level, shake: castleShake)
                    .position(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 6)

                ForEach(Array(model.active.enumerated()), id: \.element.id) { index, foe in
                    foeView(foe, index: index, path: path)
                }

                ForEach(shots) { shot in
                    ShotView(shot: shot, reduceMotion: reduceMotion, freeze: freezeShots) {
                        shots.removeAll { $0.id == shot.id }
                    }
                }

                SpeechBubble(speech: model.speech, tick: model.speechTick)
                    .position(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 80)
            }
            .onChange(of: model.lastEvent) { _, event in
                guard let event else { return }
                handle(event, path: path, towers: towers, size: size)
            }
        }
        .boardFrame()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("戦場の地図"))
    }

    // MARK: - 地面と道

    private func ground(theme: MapTheme, size: CGSize) -> some View {
        HandDrawnGround(theme: theme)
            .frame(width: size.width, height: size.height)
    }

    private func road(path: MarchPath, theme: MapTheme) -> some View {
        HandDrawnRoad(points: path.points, theme: theme)
    }

    /// 道の目盛り（残り 3 日・1 日・6 時間・1 時間）。城までの距離＝時間を、形で読めるようにする
    private func milestones(path: MarchPath) -> some View {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let marks: [(Double, LocalizedStringKey, CGFloat)] = [(72, "3日", 1), (24, "1日", 1), (6, "6時間", 1), (1, "1時間", -1)]
        return ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
            let t = Battlefield.progress(deadline: now.addingTimeInterval(mark.0 * 3600), now: now)
            let p = path.point(at: t)
            let n = path.normal(at: t)
            ZStack {
                Capsule().fill(Theme.ink.opacity(0.7)).frame(width: 2.5, height: 32)
                    .rotationEffect(.radians(Double(atan2(n.dy, n.dx)) + .pi / 2))
                    .position(p)
                Text(mark.1)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Theme.card.opacity(0.85)).overlay(Capsule().stroke(Theme.ink.opacity(0.5), lineWidth: 0.8)))
                    .position(x: p.x + n.dx * 24 * mark.2, y: p.y + n.dy * 24 * mark.2)
            }
        }
    }

    private func entrance(at point: CGPoint) -> some View {
        ZStack {
            GateShape().fill(Theme.woodGrain.opacity(0.75)).overlay(GateShape().stroke(Theme.ink, lineWidth: 1.4)).frame(width: 22, height: 20)
            Text("1週間")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 5)
                .background(Capsule().fill(Theme.card.opacity(0.85)))
                .offset(y: 19)
        }
        .position(x: point.x, y: point.y - 2)
        .accessibilityHidden(true)
    }

    // MARK: - 敵

    private func position(of foe: Foe, index: Int, path: MarchPath) -> CGPoint {
        let t = model.progress(of: foe)
        if model.stage(of: foe) == .breached {
            // 城の門の前に並ぶ
            let castle = MarchPath.castleSpot
            let column = CGFloat(index % 5) - 2
            return CGPoint(x: castle.x * path.size.width + column * 18, y: castle.y * path.size.height - 30)
        }
        return path.point(at: t, lane: foe.lane, spacing: 9)
    }

    private func foeView(_ foe: Foe, index: Int, path: MarchPath) -> some View {
        let stage = model.stage(of: foe)
        let point = position(of: foe, index: index, path: path)
        return FoeFigure(weight: foe.weight, stage: stage, progress: model.progress(of: foe), highlighted: foe.id == focusID)
            .scaleEffect(foe.id == spawnedID && !reduceMotion ? 0.3 : 1)
            .overlay(alignment: .top) {
                if foe.id == focusID {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.gold)
                        .shadow(color: Theme.ink, radius: 0, x: 0, y: 1.5)
                        .offset(y: -16)
                }
            }
            .contentShape(Circle().inset(by: -8))
            .position(point)
            .onTapGesture { onTapFoe(foe) }
            .onLongPressGesture(minimumDuration: 0.45) { onLongPressFoe(foe) }
            .accessibilityElement()
            .accessibilityLabel(Text(foe.title))
            .accessibilityValue(Text(RemainingText.key(deadline: foe.deadline, now: model.now)))
            .accessibilityHint(Text("ダブルタップで選ぶ"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("倒した")) { model.defeat(foe) }
    }

    // MARK: - できごと

    private func handle(_ event: BattleEvent, path: MarchPath, towers: [CGPoint], size: CGSize) {
        switch event.kind {
        case let .defeat(foe, progress, combo, points):
            let target = model.stage(of: foe) == .breached
                ? CGPoint(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 30)
                : path.point(at: progress, lane: foe.lane, spacing: 9)
            let nearest = towers.enumerated().min { hypot($0.element.x - target.x, $0.element.y - target.y) < hypot($1.element.x - target.x, $1.element.y - target.y) }
            let from = nearest?.element ?? CGPoint(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 30)
            firingTower = nearest?.offset
            if !freezeShots {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.18)) { firingTower = nil }
            }
            shots.append(ShotAnim(from: CGPoint(x: from.x, y: from.y - 14), to: target, foe: foe, stage: model.stage(of: foe), progress: progress, combo: combo, points: points))
        case .breach:
            guard !reduceMotion else { return }
            Task { @MainActor in
                for x in [0, -6, 5, -4, 3, -2, 0] as [CGFloat] {
                    withAnimation(.easeInOut(duration: 0.06)) { castleShake = x }
                    try? await Task.sleep(for: .milliseconds(60))
                }
            }
        case .spawn(let foe):
            guard !reduceMotion else { return }
            spawnedID = foe.id
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.05)) { spawnedID = nil }
        case .clear, .split:
            break
        }
    }
}

struct ShotAnim: Identifiable, Equatable {
    let id = UUID()
    let from: CGPoint
    let to: CGPoint
    let foe: Foe
    let stage: Stage
    let progress: Double
    let combo: Int
    let points: Int
}

/// 砲台から敵へ飛ぶ玉 → 敵がはじけて消える → 点が浮かぶ
struct ShotView: View {
    let shot: ShotAnim
    let reduceMotion: Bool
    var freeze = false
    let onFinish: @MainActor () -> Void

    @State private var flight: CGFloat = 0
    @State private var burst: CGFloat = 0
    @State private var gone = false

    var body: some View {
        let x = shot.from.x + (shot.to.x - shot.from.x) * flight
        let y = shot.from.y + (shot.to.y - shot.from.y) * flight - 96 * flight * (1 - flight)
        ZStack {
            // 弾の通り道（砲台 → 敵）。どの砲台が、どの敵を撃ったかが一目で分かる
            if !reduceMotion && flight > 0 && !gone {
                Path { p in
                    p.move(to: shot.from)
                    p.addQuadCurve(to: shot.to, control: CGPoint(x: (shot.from.x + shot.to.x) / 2, y: (shot.from.y + shot.to.y) / 2 - 48))
                }
                .trim(from: 0, to: flight)
                .stroke(Theme.ink.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 5]))
            }
            // 倒れる敵（はじけて小さくなる）
            FoeFigure(weight: shot.foe.weight, stage: shot.stage, progress: shot.progress)
                .scaleEffect(gone ? 0.01 : (burst > 0 ? 1.25 : 1))
                .opacity(gone ? 0 : 1)
                .position(shot.to)
            // 光の輪
            Circle()
                .stroke(Theme.gold, lineWidth: 4)
                .frame(width: 30, height: 30)
                .scaleEffect(0.4 + burst * 1.6)
                .opacity(burst > 0 ? Double(1 - burst) : 0)
                .position(shot.to)
            // 玉
            if flight < 1 && !reduceMotion {
                Circle().fill(Theme.gold.opacity(0.45)).frame(width: 22, height: 22).blur(radius: 3).position(x: x, y: y)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x9A9AA0), Color(hex: 0x2E2E34)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 7))
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 1))
                    .frame(width: 11, height: 11)
                    .position(x: x, y: y)
            }
            // 点
            Text(shot.combo > 1 ? "+\(shot.points)  ×\(shot.combo)" : "+\(shot.points)")
                .font(.system(size: shot.combo > 1 ? 20 : 17, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(shot.combo > 1 ? Theme.gold : Theme.cream)
                .shadow(color: Theme.ink, radius: 0, x: 1, y: 1)
                .shadow(color: Theme.ink, radius: 0, x: -1, y: 1)
                .shadow(color: Theme.ink, radius: 0, x: 1, y: -1)
                .shadow(color: Theme.ink, radius: 0, x: -1, y: -1)
                .shadow(color: Theme.ink, radius: 0, x: 0, y: 2.5)
                .opacity(burst > 0 && burst < 1 ? 1 : 0)
                .position(x: shot.to.x, y: shot.to.y - 26 - burst * 16)
        }
        .allowsHitTesting(false)
        .task {
            if freeze {
                // 撮影用：弾が敵に届く少し前で止める
                flight = 0.55
                return
            }
            if reduceMotion {
                flight = 1
                withAnimation(.easeOut(duration: 0.25)) { gone = true }
                try? await Task.sleep(for: .milliseconds(300))
                onFinish()
                return
            }
            withAnimation(.easeIn(duration: 0.26)) { flight = 1 }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeOut(duration: 0.5)) { burst = 0.99 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.08)) { gone = true }
            try? await Task.sleep(for: .milliseconds(650))
            onFinish()
        }
    }
}

/// 城の上の一言（Finch のやさしい反応にならう）
struct SpeechBubble: View {
    let speech: Speech
    let tick: Int
    @State private var visible = true

    var body: some View {
        Text(speech.text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Theme.card)
                    .shadow(color: Theme.shadowSoft, radius: 0, y: 2.5)
            )
            .overlay(Capsule().stroke(Theme.ink, lineWidth: 1.4))
            .fixedSize()
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.96)
            .id(tick)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeOut(duration: 0.25), value: tick)
            .accessibilityHidden(true)
    }
}

/// 残り時間の言い方
enum RemainingText {
    static func key(deadline: Date, now: Date) -> LocalizedStringKey {
        switch Remaining(deadline: deadline, now: now) {
        case .minutes(let n): return "あと\(n)分"
        case .hours(let n): return "あと\(n)時間"
        case .days(let n): return "あと\(n)日"
        case .overdue: return "城に届いています"
        }
    }
}

/// 手描きの地図の地面：羊皮紙に、テーマの手描きの模様（森・波・雪の丘・星）と、ふちの焼け・方位の印
struct HandDrawnGround: View {
    let theme: MapTheme

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(theme.ground))
            // 紙のしみ（固定の乱数で毎回同じ場所）
            var seed: UInt64 = 0x5EED
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 33) % 10_000) / 10_000
            }
            for _ in 0..<14 {
                let r = 20 + next() * 50
                let c = CGPoint(x: next() * size.width, y: next() * size.height)
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.7, width: r * 2, height: r * 1.4)), with: .color(Theme.woodLight.opacity(0.07)))
            }
            // 手描きの模様
            let ink = GraphicsContext.Shading.color(theme.speck.opacity(0.85))
            for _ in 0..<34 {
                let x = next() * size.width
                let y = next() * size.height
                var mark = Path()
                switch theme {
                case .meadow:
                    // 小さな木（丸い葉と幹）
                    let r = 4 + next() * 3
                    mark.addEllipse(in: CGRect(x: x - r, y: y - r * 2, width: r * 2, height: r * 1.8))
                    context.fill(mark, with: .color(theme.speck.opacity(0.35)))
                    context.stroke(mark, with: ink, lineWidth: 1)
                    var trunk = Path()
                    trunk.move(to: CGPoint(x: x, y: y - r * 0.2))
                    trunk.addLine(to: CGPoint(x: x, y: y + 2))
                    context.stroke(trunk, with: .color(Theme.ink.opacity(0.6)), lineWidth: 1.2)
                    continue
                case .harbor:
                    mark.move(to: CGPoint(x: x - 7, y: y))
                    mark.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 3.5, y: y - 4))
                    mark.addQuadCurve(to: CGPoint(x: x + 7, y: y), control: CGPoint(x: x + 3.5, y: y - 4))
                case .snow:
                    // 雪の丘（山の形）
                    mark.move(to: CGPoint(x: x - 8, y: y))
                    mark.addLine(to: CGPoint(x: x, y: y - 9))
                    mark.addLine(to: CGPoint(x: x + 8, y: y))
                    mark.move(to: CGPoint(x: x - 3, y: y - 5.5))
                    mark.addLine(to: CGPoint(x: x, y: y - 3.5))
                    mark.addLine(to: CGPoint(x: x + 3, y: y - 5.5))
                case .dusk:
                    mark.move(to: CGPoint(x: x, y: y - 4)); mark.addLine(to: CGPoint(x: x, y: y + 4))
                    mark.move(to: CGPoint(x: x - 4, y: y)); mark.addLine(to: CGPoint(x: x + 4, y: y))
                }
                context.stroke(mark, with: ink, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            }
            // 方位の印（右上）
            let cc = CGPoint(x: size.width - 30, y: 30)
            var star = Path()
            for i in 0..<8 {
                let a = Double(i) / 8 * 2 * .pi - .pi / 2
                let r: CGFloat = i % 2 == 0 ? 16 : 5
                let pt = CGPoint(x: cc.x + cos(a) * r, y: cc.y + sin(a) * r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            context.fill(star, with: .color(Theme.peachDeep.opacity(0.75)))
            context.stroke(star, with: .color(Theme.ink.opacity(0.8)), lineWidth: 1)
            context.stroke(Path(ellipseIn: CGRect(x: cc.x - 11, y: cc.y - 11, width: 22, height: 22)), with: .color(Theme.ink.opacity(0.5)), lineWidth: 0.8)
            // ふちの焼け
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [.clear, .clear, Theme.woodLight.opacity(0.45)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0, endRadius: max(size.width, size.height) * 0.75))
            // 内側の細い二重線（地図の枠）
            context.stroke(Path(roundedRect: rect.insetBy(dx: 5, dy: 5), cornerRadius: 8), with: .color(Theme.ink.opacity(0.35)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// 手描きの道：インクの縁・土の色・足あとの点線
struct HandDrawnRoad: View {
    let points: [CGPoint]
    let theme: MapTheme
    var width: CGFloat = 24

    var body: some View {
        Canvas { context, _ in
            var line = Path()
            line.addLines(points)
            context.stroke(line, with: .color(Theme.ink.opacity(0.75)), style: StrokeStyle(lineWidth: width + 4, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(theme.road), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(Color.white.opacity(0.18)), style: StrokeStyle(lineWidth: width * 0.4, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(Theme.ink.opacity(0.45)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 8]))
        }
        .accessibilityHidden(true)
    }
}
