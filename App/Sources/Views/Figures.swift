import SwiftUI

// 地図の部品。題材の現物（締め切り＝時計、今日の自分＝城、済ませる力＝砲台）を自作の形で描く。

/// しめきりの敵：丸い体に時計の顔。針は城までの残りを指す。大きさ＝重さ
struct FoeFigure: View {
    var weight: Int
    var stage: Stage
    /// 0 = 入口、1 = 城
    var progress: Double
    var highlighted = false

    static func diameter(weight: Int) -> CGFloat {
        switch weight {
        case 1: return 24
        case 2: return 32
        default: return 42
        }
    }

    var body: some View {
        let d = Self.diameter(weight: weight)
        ZStack {
            // 足（2 つの小さな丸）
            HStack(spacing: d * 0.22) {
                Capsule().fill(Theme.foeOutline(stage).opacity(0.55)).frame(width: d * 0.2, height: d * 0.13)
                Capsule().fill(Theme.foeOutline(stage).opacity(0.55)).frame(width: d * 0.2, height: d * 0.13)
            }
            .offset(y: d * 0.47)
            // 体
            Circle()
                .fill(Theme.foeBody(stage))
                .overlay(Circle().stroke(Theme.foeOutline(stage), lineWidth: highlighted ? 2 : 1))
                .frame(width: d, height: d)
            // 時計の顔
            ClockFace(remaining: 1 - progress, stage: stage)
                .frame(width: d * 0.62, height: d * 0.62)
            // 重い敵は頭に小さな角
            if weight >= 3 {
                HStack(spacing: d * 0.34) {
                    Horn().fill(Theme.foeOutline(stage).opacity(0.8)).frame(width: d * 0.14, height: d * 0.16)
                    Horn().fill(Theme.foeOutline(stage).opacity(0.8)).frame(width: d * 0.14, height: d * 0.16)
                }
                .offset(y: -d * 0.52)
            }
            if stage == .breached {
                Circle().fill(Theme.peachDeep).frame(width: 8, height: 8)
                    .offset(x: d * 0.42, y: -d * 0.4)
            }
        }
        .frame(width: d + 8, height: d + 12)
        .shadow(color: Theme.shadowSoft, radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

/// 時計の顔：白い文字盤に、残りの割合の淡い扇と 2 本の針
struct ClockFace: View {
    var remaining: Double
    var stage: Stage

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let r = min(size.width, size.height) / 2
            context.fill(Path(ellipseIn: rect), with: .color(Theme.card))
            let clamped = min(max(remaining, 0), 1)
            if clamped > 0 {
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: r * 0.82, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * clamped), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Theme.foeBody(stage).opacity(0.55)))
            }
            let angle = Angle.degrees(-90 + 360 * clamped).radians
            var hand = Path()
            hand.move(to: center)
            hand.addLine(to: CGPoint(x: center.x + cos(angle) * r * 0.72, y: center.y + sin(angle) * r * 0.72))
            hand.move(to: center)
            hand.addLine(to: CGPoint(x: center.x, y: center.y - r * 0.48))
            context.stroke(hand, with: .color(Theme.ink.opacity(0.75)), style: StrokeStyle(lineWidth: max(1, r * 0.12), lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.1, y: center.y - r * 0.1, width: r * 0.2, height: r * 0.2)), with: .color(Theme.ink))
        }
    }
}

struct Horn: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

/// 城（今日の自分）：3 つの塔と門。守りの旗が上に並ぶ
struct CastleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let towerW = w * 0.24
        let wallTop = rect.minY + h * 0.38
        // 左右の塔
        for x in [rect.minX, rect.maxX - towerW] {
            p.addPath(Self.tower(CGRect(x: x, y: rect.minY + h * 0.12, width: towerW, height: h * 0.88)))
        }
        // まんなかの塔
        p.addPath(Self.tower(CGRect(x: rect.midX - towerW * 0.6, y: rect.minY, width: towerW * 1.2, height: h)))
        // 壁
        p.addRect(CGRect(x: rect.minX + towerW * 0.5, y: wallTop, width: w - towerW, height: rect.maxY - wallTop))
        return p
    }

    /// 上が凸凹の塔
    static func tower(_ r: CGRect) -> Path {
        var p = Path()
        let notch = r.width / 5
        let notchH = min(r.height * 0.1, notch)
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        for i in 0..<5 {
            let x0 = r.minX + CGFloat(i) * notch
            let up = i % 2 == 0
            p.addLine(to: CGPoint(x: x0, y: up ? r.minY : r.minY + notchH))
            p.addLine(to: CGPoint(x: x0 + notch, y: up ? r.minY : r.minY + notchH))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// 門（城の下のまんなか）
struct GateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct CastleFigure: View {
    var health: Int
    var level: Int
    var shake: CGFloat = 0

    var body: some View {
        VStack(spacing: 3) {
            // 守り（10 本の小さな旗の棒）
            HStack(spacing: 2) {
                ForEach(0..<Battlefield.castleMax, id: \.self) { i in
                    Capsule()
                        .fill(i < health ? Theme.sky : Theme.peachSoft)
                        .frame(width: 3, height: 7)
                }
            }
            ZStack(alignment: .bottom) {
                CastleShape()
                    .fill(Theme.card)
                    .overlay(CastleShape().stroke(Theme.skyDeep.opacity(0.85), lineWidth: 1))
                GateShape()
                    .fill(Theme.skySoft)
                    .overlay(GateShape().stroke(Theme.skyDeep.opacity(0.7), lineWidth: 0.8))
                    .frame(width: 14, height: 16)
                // 旗：レベルが上がると色の付いた旗が増える
                HStack(spacing: 18) {
                    ForEach(0..<min(3, 1 + level / 3), id: \.self) { _ in
                        Pennant().fill(Theme.tape.opacity(0.9)).frame(width: 9, height: 7)
                    }
                }
                .offset(y: -50)
            }
            .frame(width: 66, height: 44)
        }
        .offset(x: shake)
        .accessibilityHidden(true)
    }
}

struct Pennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 砲台：丸い台に砲身。種類で頭の形が変わる
struct TowerFigure: View {
    var kind: TowerKind
    var firing = false

    var body: some View {
        ZStack {
            Ellipse().fill(Theme.ink.opacity(0.06)).frame(width: 26, height: 8).offset(y: 12)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Theme.skyDeep.opacity(0.8), lineWidth: 1))
                .frame(width: 20, height: 18)
                .offset(y: 3)
            head
                .offset(y: -8)
        }
        .scaleEffect(firing ? 1.12 : 1)
        .frame(width: 30, height: 34)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var head: some View {
        switch kind {
        case .basic:
            Circle().fill(Theme.sky).overlay(Circle().stroke(Theme.skyDeep, lineWidth: 1)).frame(width: 12, height: 12)
        case .morning:
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Capsule().fill(Theme.butter).frame(width: 2, height: 5).offset(y: -9).rotationEffect(.degrees(Double(i) * 45))
                }
                Circle().fill(Theme.butter).overlay(Circle().stroke(Theme.peachDeep.opacity(0.8), lineWidth: 1)).frame(width: 12, height: 12)
            }
        case .rapid:
            HStack(spacing: 2) {
                Circle().fill(Theme.lavender).overlay(Circle().stroke(Theme.skyDeep, lineWidth: 1)).frame(width: 9, height: 9)
                Circle().fill(Theme.lavender).overlay(Circle().stroke(Theme.skyDeep, lineWidth: 1)).frame(width: 9, height: 9)
            }
        }
    }
}

/// 紙のテープ（StudyReel の TapeShape にならう：両端がぎざぎざ）。共有カードと見出しの飾りに少しだけ
struct TapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let teeth = 4
        let depth: CGFloat = min(4, rect.width * 0.05)
        let step = rect.height / CGFloat(teeth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        for i in 0..<teeth {
            let y = rect.minY + CGFloat(i) * step
            p.addLine(to: CGPoint(x: rect.maxX - depth, y: y + step / 2))
            p.addLine(to: CGPoint(x: rect.maxX, y: y + step))
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in (0..<teeth).reversed() {
            let y = rect.minY + CGFloat(i) * step
            p.addLine(to: CGPoint(x: rect.minX + depth, y: y + step / 2))
            p.addLine(to: CGPoint(x: rect.minX, y: y))
        }
        p.closeSubpath()
        return p
    }
}
