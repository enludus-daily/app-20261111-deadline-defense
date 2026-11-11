import SwiftUI

/// 戦場の地図：道・敵・城・砲台。文字を読まずに「何が近いか」が分かることを目標にする
struct MapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var focusID: UUID?
    var onTapFoe: (Foe) -> Void = { _ in }
    var onLongPressFoe: (Foe) -> Void = { _ in }

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
            let towers = Array(MarchPath.towerSpots.prefix(min(MarchPath.towerSpots.count, 2 + level / 2)))
            ZStack {
                ground(theme: theme, size: size)
                road(path: path, theme: theme)
                milestones(path: path)
                entrance(at: path.point(at: 0))

                ForEach(Array(towers.enumerated()), id: \.offset) { index, spot in
                    TowerFigure(kind: model.effectiveTower, firing: firingTower == index)
                        .position(x: spot.x * size.width, y: spot.y * size.height)
                }

                CastleFigure(health: model.castleHealth, level: level, shake: castleShake)
                    .position(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 6)

                ForEach(Array(model.active.enumerated()), id: \.element.id) { index, foe in
                    foeView(foe, index: index, path: path)
                }

                ForEach(shots) { shot in
                    ShotView(shot: shot, reduceMotion: reduceMotion) {
                        shots.removeAll { $0.id == shot.id }
                    }
                }

                SpeechBubble(speech: model.speech, tick: model.speechTick)
                    .position(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 70)
            }
            .onChange(of: model.lastEvent) { _, event in
                guard let event else { return }
                handle(event, path: path, towers: towers, size: size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("戦場の地図"))
    }

    // MARK: - 地面と道

    private func ground(theme: MapTheme, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(theme.ground))
            // 固定の乱数で、毎回同じ場所に小さな模様を置く（撮影とテストが安定する）
            var seed: UInt64 = 0x5EED
            for _ in 0..<70 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat((seed >> 33) % 1000) / 1000 * canvasSize.width
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let y = CGFloat((seed >> 33) % 1000) / 1000 * canvasSize.height
                var mark = Path()
                switch theme {
                case .meadow:
                    mark.move(to: CGPoint(x: x - 3, y: y)); mark.addLine(to: CGPoint(x: x - 1, y: y - 4))
                    mark.move(to: CGPoint(x: x + 1, y: y)); mark.addLine(to: CGPoint(x: x + 3, y: y - 5))
                case .harbor:
                    mark.move(to: CGPoint(x: x - 5, y: y))
                    mark.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 2.5, y: y - 3))
                    mark.addQuadCurve(to: CGPoint(x: x + 5, y: y), control: CGPoint(x: x + 2.5, y: y - 3))
                case .snow:
                    mark.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                case .dusk:
                    mark.move(to: CGPoint(x: x, y: y - 3)); mark.addLine(to: CGPoint(x: x, y: y + 3))
                    mark.move(to: CGPoint(x: x - 3, y: y)); mark.addLine(to: CGPoint(x: x + 3, y: y))
                }
                context.stroke(mark, with: .color(theme.speck.opacity(0.7)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func road(path: MarchPath, theme: MapTheme) -> some View {
        Canvas { context, _ in
            var line = Path()
            line.addLines(path.points)
            context.stroke(line, with: .color(Theme.line), style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(theme.road), style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
            context.stroke(line, with: .color(Theme.card.opacity(0.9)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 7]))
        }
    }

    /// 道の目盛り（残り 3 日・1 日・6 時間・1 時間）。城までの距離＝時間を、形で読めるようにする
    private func milestones(path: MarchPath) -> some View {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let marks: [(Double, LocalizedStringKey)] = [(72, "3日"), (24, "1日"), (6, "6時間"), (1, "1時間")]
        return ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
            let t = Battlefield.progress(deadline: now.addingTimeInterval(mark.0 * 3600), now: now)
            let p = path.point(at: t)
            let n = path.normal(at: t)
            ZStack {
                Capsule().fill(Theme.sub.opacity(0.45)).frame(width: 2, height: 30)
                    .rotationEffect(.radians(Double(atan2(n.dy, n.dx)) + .pi / 2))
                    .position(p)
                Text(mark.1)
                    .font(.system(size: 9, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Theme.sub)
                    .position(x: p.x + n.dx * 24, y: p.y + n.dy * 24)
            }
        }
    }

    private func entrance(at point: CGPoint) -> some View {
        ZStack {
            GateShape().stroke(Theme.sub.opacity(0.7), lineWidth: 1).frame(width: 22, height: 20)
            Text("1週間").font(.system(size: 9, weight: .medium)).kerning(0.6).foregroundStyle(Theme.sub).offset(y: 18)
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
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.skyDeep)
                        .offset(y: -12)
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
            let scaled = towers.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            let nearest = scaled.enumerated().min { hypot($0.element.x - target.x, $0.element.y - target.y) < hypot($1.element.x - target.x, $1.element.y - target.y) }
            let from = nearest?.element ?? CGPoint(x: MarchPath.castleSpot.x * size.width, y: MarchPath.castleSpot.y * size.height - 30)
            firingTower = nearest?.offset
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.18)) { firingTower = nil }
            shots.append(ShotAnim(from: CGPoint(x: from.x, y: from.y - 10), to: target, foe: foe, stage: .near, progress: progress, combo: combo, points: points))
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
    let onFinish: @MainActor () -> Void

    @State private var flight: CGFloat = 0
    @State private var burst: CGFloat = 0
    @State private var gone = false

    var body: some View {
        let x = shot.from.x + (shot.to.x - shot.from.x) * flight
        let y = shot.from.y + (shot.to.y - shot.from.y) * flight - sin(flight * .pi) * 24
        ZStack {
            // 倒れる敵（はじけて小さくなる）
            FoeFigure(weight: shot.foe.weight, stage: shot.stage, progress: shot.progress)
                .scaleEffect(gone ? 0.01 : (burst > 0 ? 1.25 : 1))
                .opacity(gone ? 0 : 1)
                .position(shot.to)
            // 光の輪
            Circle()
                .stroke(Theme.sky, lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(0.4 + burst * 1.6)
                .opacity(burst > 0 ? Double(1 - burst) : 0)
                .position(shot.to)
            // 玉
            if flight < 1 && !reduceMotion {
                Circle().fill(Theme.skyDeep).frame(width: 7, height: 7).position(x: x, y: y)
            }
            // 点
            Text(shot.combo > 1 ? "+\(shot.points)  ×\(shot.combo)" : "+\(shot.points)")
                .font(Theme.serif(15, .medium))
                .monospacedDigit()
                .foregroundStyle(shot.combo > 1 ? Theme.peachDeep : Theme.skyDeep)
                .opacity(burst > 0 && burst < 1 ? 1 : 0)
                .position(x: shot.to.x, y: shot.to.y - 26 - burst * 16)
        }
        .allowsHitTesting(false)
        .task {
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
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Theme.card)
                    .shadow(color: Theme.shadowSoft, radius: 6, y: 3)
            )
            .overlay(Capsule().stroke(Theme.line, lineWidth: 0.8))
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
