import SwiftUI
import UIKit

// 盤の上のコマ。題材の現物（締め切り＝目覚まし時計、今日の自分＝城、済ませる力＝塔）を、立体のミニチュアとして自作の形で描く。

/// しめきりの敵：真鍮の目覚まし時計のコマ。上に 2 つのベル、下に足。針は城までの残りを指す。大きさ＝重さ
/// 立体に見せる：上から光の当たる丸い体（放射のグラデーション）・太いインクの縁・盤に落ちる影
struct FoeFigure: View {
    var weight: Int
    var stage: Stage
    /// 0 = 入口、1 = 城
    var progress: Double
    var highlighted = false

    static func diameter(weight: Int) -> CGFloat {
        switch weight {
        case 1: return 30
        case 2: return 38
        default: return 48
        }
    }

    var body: some View {
        let d = Self.diameter(weight: weight)
        let fill = Theme.foeBody(stage)
        let outline = Theme.foeOutline(stage)
        let lw: CGFloat = highlighted ? 2.4 : 1.6
        ZStack {
            // 盤に落ちる影
            Ellipse().fill(Theme.woodGrain.opacity(0.28)).frame(width: d * 0.95, height: d * 0.26).offset(y: d * 0.52)
            // 足
            HStack(spacing: d * 0.3) {
                Capsule().fill(outline).frame(width: d * 0.12, height: d * 0.22).rotationEffect(.degrees(25))
                Capsule().fill(outline).frame(width: d * 0.12, height: d * 0.22).rotationEffect(.degrees(-25))
            }
            .offset(y: d * 0.45)
            // ベル（目覚まし時計）
            HStack(spacing: d * 0.36) {
                Bell().fill(fill).overlay(Bell().stroke(outline, lineWidth: lw * 0.8)).frame(width: d * 0.3, height: d * 0.24).rotationEffect(.degrees(-28))
                Bell().fill(fill).overlay(Bell().stroke(outline, lineWidth: lw * 0.8)).frame(width: d * 0.3, height: d * 0.24).rotationEffect(.degrees(28))
            }
            .offset(y: -d * 0.44)
            // 体の厚み（下の濃い縁）
            Circle().fill(outline).frame(width: d, height: d).offset(y: d * 0.06)
            // 体
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.9), fill, fill.mix(Theme.ink, 0.25)], center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: d * 0.72))
                .overlay(Circle().stroke(outline, lineWidth: lw))
                .frame(width: d, height: d)
            // 時計の顔
            ClockFace(remaining: 1 - progress, stage: stage)
                .frame(width: d * 0.66, height: d * 0.66)
                .overlay(Circle().stroke(outline.opacity(0.8), lineWidth: 1))
            // 重い敵は怒った眉
            if weight >= 3 {
                HStack(spacing: d * 0.1) {
                    Capsule().fill(outline).frame(width: d * 0.2, height: d * 0.07).rotationEffect(.degrees(22))
                    Capsule().fill(outline).frame(width: d * 0.2, height: d * 0.07).rotationEffect(.degrees(-22))
                }
                .offset(y: -d * 0.2)
            }
            // つや
            Ellipse().fill(Color.white.opacity(0.55)).frame(width: d * 0.22, height: d * 0.12).rotationEffect(.degrees(-35)).offset(x: -d * 0.3, y: -d * 0.3)
            if stage == .breached {
                Text(verbatim: "!")
                    .font(.system(size: d * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .frame(width: d * 0.36, height: d * 0.36)
                    .background(Circle().fill(Theme.peachDeep).overlay(Circle().stroke(Theme.cream, lineWidth: 1.2)))
                    .offset(x: d * 0.44, y: -d * 0.4)
            }
        }
        .frame(width: d + 8, height: d + 12)
        .accessibilityHidden(true)
    }
}

/// 目覚まし時計のベル（半円）
struct Bell: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.closeSubpath()
        return p
    }
}

extension Color {
    /// 2 色を混ぜる（影の色を作る）
    func mix(_ other: Color, _ amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(amount)
        return Color(.sRGB, red: Double(r1 + (r2 - r1) * t), green: Double(g1 + (g2 - g1) * t), blue: Double(b1 + (b2 - b1) * t), opacity: Double(a1 + (a2 - a1) * t))
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
            context.fill(Path(ellipseIn: rect), with: .color(Theme.cream))
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cos(a) * r * 0.82, y: center.y + sin(a) * r * 0.82))
                tick.addLine(to: CGPoint(x: center.x + cos(a) * r * (i % 3 == 0 ? 0.64 : 0.74), y: center.y + sin(a) * r * (i % 3 == 0 ? 0.64 : 0.74)))
                context.stroke(tick, with: .color(Theme.ink.opacity(0.6)), lineWidth: max(0.6, r * (i % 3 == 0 ? 0.1 : 0.05)))
            }
            let clamped = min(max(remaining, 0), 1)
            if clamped > 0 {
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: r * 0.82, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * clamped), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(Theme.foeBody(stage).opacity(0.45)))
            }
            let angle = Angle.degrees(-90 + 360 * clamped).radians
            var hand = Path()
            hand.move(to: center)
            hand.addLine(to: CGPoint(x: center.x + cos(angle) * r * 0.72, y: center.y + sin(angle) * r * 0.72))
            hand.move(to: center)
            hand.addLine(to: CGPoint(x: center.x, y: center.y - r * 0.48))
            context.stroke(hand, with: .color(Theme.ink), style: StrokeStyle(lineWidth: max(1.2, r * 0.15), lineCap: .round))
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
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                // 盤に落ちる影
                Ellipse().fill(Theme.woodGrain.opacity(0.3)).frame(width: 84, height: 14).offset(y: 6)
                // 壁の厚み（右下にずらした濃い面）
                CastleShape()
                    .fill(Color(hex: 0x7E705C))
                    .offset(x: 2, y: 3)
                CastleShape()
                    .fill(LinearGradient(colors: [Color(hex: 0xE9DFC8), Color(hex: 0xBFAF92)], startPoint: .top, endPoint: .bottom))
                    .overlay(StoneLines().stroke(Theme.ink.opacity(0.25), lineWidth: 0.6).clipShape(CastleShape()))
                    .overlay(CastleShape().stroke(Theme.ink, lineWidth: 1.4))
                GateShape()
                    .fill(LinearGradient(colors: [Theme.woodDeep, Theme.wood], startPoint: .top, endPoint: .bottom))
                    .overlay(GateShape().stroke(Theme.ink, lineWidth: 1.2))
                    .frame(width: 16, height: 18)
                // 青い屋根（3 つの塔の上）
                HStack(alignment: .bottom, spacing: 0) {
                    Roof().frame(width: 18, height: 14).offset(y: 4)
                    Spacer(minLength: 0)
                    Roof().frame(width: 22, height: 18)
                    Spacer(minLength: 0)
                    Roof().frame(width: 18, height: 14).offset(y: 4)
                }
                .frame(width: 70)
                .offset(y: -40)
                // 旗：レベルが上がると旗が増える
                HStack(spacing: 13) {
                    ForEach(0..<min(3, 1 + level / 3), id: \.self) { i in
                        Flag(color: i == 1 ? Theme.gold : Theme.peach)
                    }
                }
                .offset(y: -58)
            }
            .frame(width: 66, height: 44)
            .overlay(alignment: .top) {
                HStack(spacing: 1.5) {
                    ForEach(0..<Battlefield.castleMax, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(i < health ? Theme.sky : Theme.peach.opacity(0.35))
                            .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Theme.ink.opacity(0.7), lineWidth: 0.6))
                            .frame(width: 4, height: 7)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.wood).overlay(Capsule().stroke(Theme.woodGrain, lineWidth: 1)))
                .offset(y: -40)
            }
        }
        // 前と同じ高さ（63）にして、地図の上の位置を変えない
        .padding(.top, 19)
        .offset(x: shake)
        .accessibilityHidden(true)
    }
}

/// 青い円すいの屋根
struct Roof: View {
    var color: Color = Theme.skyDeep

    var body: some View {
        ZStack {
            Triangle().fill(LinearGradient(colors: [Theme.sky, color], startPoint: .leading, endPoint: .trailing))
            Triangle().stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 小さな旗（棒と三角）
struct Flag: View {
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(Theme.ink).frame(width: 1.2, height: 10)
            Pennant().fill(color).overlay(Pennant().stroke(Theme.ink, lineWidth: 0.8)).frame(width: 9, height: 6)
        }
        .frame(width: 11, height: 10, alignment: .leading)
    }
}

/// 石積みの線
struct StoneLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let row: CGFloat = 6
        var y = rect.minY + row
        var odd = false
        while y < rect.maxY {
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
            var x = rect.minX + (odd ? 4 : 0)
            while x < rect.maxX {
                p.move(to: CGPoint(x: x, y: y - row))
                p.addLine(to: CGPoint(x: x, y: y))
                x += 9
            }
            odd.toggle()
            y += row
        }
        return p
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

/// 砲台：石の小さな塔に、色の付いた円すいの屋根。屋根の色と窓の形で種類が分かる
struct TowerFigure: View {
    var kind: TowerKind
    var firing = false

    private var roofColor: Color {
        switch kind {
        case .basic: return Theme.skyDeep
        case .morning: return Theme.goldDeep
        case .rapid: return Theme.lavender
        }
    }

    var body: some View {
        ZStack {
            Ellipse().fill(Theme.woodGrain.opacity(0.3)).frame(width: 30, height: 9).offset(y: 15)
            TowerBody()
                .fill(Color(hex: 0x7E705C))
                .frame(width: 20, height: 24)
                .offset(x: 1.5, y: 5)
            TowerBody()
                .fill(LinearGradient(colors: [Color(hex: 0xEDE3CC), Color(hex: 0xB5A585)], startPoint: .leading, endPoint: .trailing))
                .overlay(TowerBody().stroke(Theme.ink, lineWidth: 1.2))
                .frame(width: 20, height: 24)
                .offset(y: 3)
            window
                .offset(y: 6)
            ZStack {
                Triangle().fill(LinearGradient(colors: [roofColor.opacity(0.7), roofColor], startPoint: .leading, endPoint: .trailing))
                Triangle().stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
            }
            .frame(width: 24, height: 15)
            .offset(y: -15)
            if kind == .morning {
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(Theme.gold).frame(width: 2, height: 4)
                        .offset(y: -9)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .offset(y: -22)
                }
            }
            if firing {
                Circle().fill(Theme.gold.opacity(0.8)).frame(width: 12, height: 12).blur(radius: 2).offset(y: -20)
            }
        }
        .scaleEffect(firing ? 1.15 : 1)
        .frame(width: 30, height: 36)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var window: some View {
        switch kind {
        case .basic, .morning:
            GateShape().fill(Theme.woodGrain).frame(width: 6, height: 8)
        case .rapid:
            HStack(spacing: 2) {
                GateShape().fill(Theme.woodGrain).frame(width: 4, height: 8)
                GateShape().fill(Theme.woodGrain).frame(width: 4, height: 8)
            }
        }
    }
}

struct TowerBody: Shape {
    func path(in rect: CGRect) -> Path { CastleShape.tower(rect) }
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
