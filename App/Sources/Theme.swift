import SwiftUI

// 色・書体・形を 1 か所で決める（app-quality-bar look.md §2〜4）。
// 世界：木のテーブルの上の、ミニチュアの城とボードゲーム（2026-11-16 の作り直し）。
// 地＝木のテーブル（濃い茶）、盤と札＝羊皮紙、自分の側＝王の青、敵＝真鍮の時計（近いほど赤）。
// 見出しと数字は太い丸ゴシック（ゲームの題字）、本文はサンセリフ。線は茶色のインクで太め。
// 画面はライトに固定する（木と羊皮紙の色が世界観の中心のため）。

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    // 木のテーブル（いちばん下の地）
    static var woodLight: Color { Color(hex: 0xA86F40) }
    static var wood: Color { Color(hex: 0x7D4B27) }
    static var woodDeep: Color { Color(hex: 0x4B2A14) }
    static var woodGrain: Color { Color(hex: 0x3A1F0E) }
    /// 木の上の文字（羊皮紙より明るいクリーム）
    static var cream: Color { Color(hex: 0xFFF3D6) }
    static var creamSub: Color { Color(hex: 0xE9CFA3) }

    // 羊皮紙（盤・札・シートの地）・文字・線
    static var paper: Color { Color(hex: 0xF2E0B6) }
    static var card: Color { Color(hex: 0xFBF0D3) }
    static var ink: Color { Color(hex: 0x3A2312) }
    static var sub: Color { Color(hex: 0x7D5C3A) }
    static var line: Color { Color(hex: 0xC9A469) }

    // 王の青（自分の側：城・塔・主なボタン）の 5 段階
    static var sky: Color { Color(hex: 0x5E8FDC) }
    static var skySoft: Color { Color(hex: 0xE6D2A0) }
    static var skyDeep: Color { Color(hex: 0x2A57AA) }
    static var skyEdge: Color { Color(hex: 0x173A7A) }
    static var skyPaper: Color { Color(hex: 0xF8EACA) }
    /// 金（旗・連続・見本の札）
    static var tape: Color { Color(hex: 0xE9B43A) }
    static var gold: Color { Color(hex: 0xF3C64B) }
    static var goldDeep: Color { Color(hex: 0xB07A12) }

    // 赤（城の前・届いた敵・大事な一言）
    static var peach: Color { Color(hex: 0xE2553A) }
    static var peachSoft: Color { Color(hex: 0xF2C3A6) }
    static var peachDeep: Color { Color(hex: 0xA6301F) }

    // 段階の色（敵の位置で変わる：真鍮 → 橙 → 赤）
    static var butter: Color { Color(hex: 0xF0C24E) }
    static var orange: Color { Color(hex: 0xEE8A35) }
    static var mint: Color { Color(hex: 0x6FAE55) }
    static var lavender: Color { Color(hex: 0x8B69C6) }

    /// 敵の体の色（遠い＝真鍮、近い＝橙、城の前＝赤、届いた＝淡い赤）
    static func foeBody(_ stage: Stage) -> Color {
        switch stage {
        case .far: return butter
        case .near: return orange
        case .gate: return peach
        case .breached: return peachSoft
        }
    }

    static func foeOutline(_ stage: Stage) -> Color {
        stage >= .gate ? Color(hex: 0x5E140A) : ink
    }

    // 書体：見出しと数字は太い丸ゴシック（ゲームの題字）、本文はサンセリフ
    static func display(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight == .regular ? .bold : .heavy, design: .rounded)
    }

    static func sans(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    // 角丸
    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 18

    // 影（盤に置いたコマ・テーブルに置いた札）
    static var shadowSoft: Color { Color(hex: 0x2A1608, opacity: 0.22) }
    static var shadowFloat: Color { Color(hex: 0x2A1608, opacity: 0.4) }
}

/// 木のテーブル：濃い茶の地に、ゆるい木目の線（固定の乱数で毎回同じ）
struct WoodTable: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Theme.wood, Theme.woodDeep]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
            // 板の継ぎ目
            let plank: CGFloat = 92
            var x: CGFloat = -20
            var seed: UInt64 = 0x7AB1E
            while x < size.width + plank {
                var seam = Path()
                seam.move(to: CGPoint(x: x, y: 0))
                seam.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(seam, with: .color(Theme.woodGrain.opacity(0.55)), lineWidth: 1.5)
                // 木目（波打つ細い線）
                for i in 0..<5 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let offset = CGFloat((seed >> 33) % 80) + 6
                    let amp = CGFloat((seed >> 20) % 7) + 2
                    var grain = Path()
                    let gx = x + offset
                    grain.move(to: CGPoint(x: gx, y: 0))
                    var y: CGFloat = 0
                    while y < size.height {
                        let dx = sin((y + CGFloat(i) * 37) / 70) * amp
                        grain.addLine(to: CGPoint(x: gx + dx, y: y))
                        y += 12
                    }
                    context.stroke(grain, with: .color((i % 2 == 0 ? Theme.woodGrain : Theme.woodLight).opacity(0.22)), lineWidth: i % 2 == 0 ? 1 : 0.8)
                }
                x += plank
            }
            // 上からの明かり（まんなかが少し明るい）
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [Theme.woodLight.opacity(0.35), .clear]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.18), startRadius: 0, endRadius: max(size.width, size.height) * 0.8))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 盤の木の縁：太い木枠と、内側の溝。地図・見本の場面を囲む
struct BoardFrame: ViewModifier {
    var radius: CGFloat = Theme.radiusL
    var width: CGFloat = 9

    func body(content: Self.Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius - 4, style: .continuous))
            .padding(width)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.woodLight, Theme.wood, Theme.woodDeep], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.woodGrain, lineWidth: 1.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius - width + 2, style: .continuous)
                            .stroke(Theme.woodGrain.opacity(0.7), lineWidth: 2)
                            .padding(width - 2)
                    )
                    .shadow(color: Theme.shadowFloat, radius: 0, y: 5)
                    .shadow(color: Theme.shadowFloat, radius: 12, y: 8)
            )
    }
}

/// テーブルに置いた羊皮紙の札：羊皮紙の地・茶のインクの縁・下に落ちる影
struct ParchmentCard: ViewModifier {
    var radius: CGFloat = Theme.radiusM
    var fill: Color = Theme.card
    var lifted = true

    func body(content: Self.Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius - 3, style: .continuous)
                            .stroke(Theme.line.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .padding(4)
                    )
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.ink.opacity(0.55), lineWidth: 1.5))
                    .shadow(color: lifted ? Theme.shadowSoft : .clear, radius: 0, y: 3)
            )
    }
}

extension View {
    func boardFrame(radius: CGFloat = Theme.radiusL, width: CGFloat = 9) -> some View {
        modifier(BoardFrame(radius: radius, width: width))
    }

    func parchmentCard(radius: CGFloat = Theme.radiusM, fill: Color = Theme.card, lifted: Bool = true) -> some View {
        modifier(ParchmentCard(radius: radius, fill: fill, lifted: lifted))
    }
}

/// 立体のボタンの地：下に濃い縁（押すと沈む）と、上の光。ボードゲームの厚紙のトークン
struct ChunkyFill<S: InsettableShape>: View {
    var shape: S
    var color: Color = Theme.skyDeep
    var edge: Color = Theme.skyEdge

    var body: some View {
        ZStack {
            shape.fill(edge).offset(y: 3)
            shape.fill(LinearGradient(colors: [color.opacity(0.88), color], startPoint: .top, endPoint: .bottom))
            shape.inset(by: 2.5).stroke(Color.white.opacity(0.28), lineWidth: 1.5)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            shape.stroke(edge, lineWidth: 1.5)
        }
    }
}

/// ゲームの題字：太い丸ゴシックに、濃い縁取りと落ちる影
struct GameTitle: View {
    let text: LocalizedStringKey
    var size: CGFloat = 26
    var fill: Color = Theme.gold
    var edge: Color = Theme.woodGrain

    var body: some View {
        let font = Font.system(size: size, weight: .black, design: .rounded)
        Text(text)
            .font(font)
            .kerning(-0.3)
            .foregroundStyle(LinearGradient(colors: [Color.white.opacity(0.95), fill, fill], startPoint: .top, endPoint: .bottom))
            .shadow(color: edge, radius: 0, x: 1.2, y: 1.2)
            .shadow(color: edge, radius: 0, x: -1.2, y: 1.2)
            .shadow(color: edge, radius: 0, x: 1.2, y: -1.2)
            .shadow(color: edge, radius: 0, x: -1.2, y: -1.2)
            .shadow(color: edge, radius: 0, x: 0, y: 3.5)
            .shadow(color: Color.black.opacity(0.35), radius: 4, y: 5)
    }
}

/// 地図のテーマ。meadow は無料、ほかは Pro
enum MapTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case meadow, harbor, snow, dusk

    var id: String { rawValue }
    var isPro: Bool { self != .meadow }

    var name: LocalizedStringKey {
        switch self {
        case .meadow: return "草原"
        case .harbor: return "港"
        case .snow: return "雪原"
        case .dusk: return "夕暮れ"
        }
    }

    var ground: Color {
        switch self {
        case .meadow: return Color(hex: 0xEAD9A8)
        case .harbor: return Color(hex: 0xDCD9BC)
        case .snow: return Color(hex: 0xF1EBDD)
        case .dusk: return Color(hex: 0xE9C69C)
        }
    }

    var road: Color {
        switch self {
        case .meadow: return Color(hex: 0xD2AE70)
        case .harbor: return Color(hex: 0xD6B47C)
        case .snow: return Color(hex: 0xCDBFA6)
        case .dusk: return Color(hex: 0xC99868)
        }
    }

    /// 地図の手描きの模様（森・波・雪の丘・星）
    var speck: Color {
        switch self {
        case .meadow: return Color(hex: 0x4F8A3C)
        case .harbor: return Color(hex: 0x3D6FA8)
        case .snow: return Color(hex: 0x8C9BB0)
        case .dusk: return Color(hex: 0xA8452C)
        }
    }
}
