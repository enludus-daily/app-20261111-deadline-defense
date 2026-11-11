import SwiftUI

// 色・書体・形を 1 か所で決める（app-quality-bar look.md §0・§2〜4）。
// トーンは StudyReel：淡い sky を主に、peach を差し色。主な色は明度 0.72〜0.86。
// 画面はライトに固定する（淡い地図の色が世界観の中心で、ダークでは地図が沈むため）。

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
    // 地・文字・線
    static var paper: Color { Color(hex: 0xF3F6F9) }
    static var card: Color { Color(hex: 0xFBFCFD) }
    static var ink: Color { Color(hex: 0x2E3A46) }
    static var sub: Color { Color(hex: 0x8E9AA6) }
    static var line: Color { Color(hex: 0xE3E9EF) }

    // sky（主）の 5 段階
    static var sky: Color { Color(hex: 0x9EC3E2) }
    static var skySoft: Color { Color(hex: 0xE1EDF6) }
    static var skyDeep: Color { Color(hex: 0x5E8DB8) }
    static var skyPaper: Color { Color(hex: 0xF7F8FA) }
    static var tape: Color { Color(hex: 0xF2CBD0) }

    // peach（差し色）：城の前・届いた敵・大事な一言
    static var peach: Color { Color(hex: 0xF4BBA4) }
    static var peachSoft: Color { Color(hex: 0xFBE6DC) }
    static var peachDeep: Color { Color(hex: 0xC9826A) }

    // 段階の色（敵の位置で変わる）
    static var butter: Color { Color(hex: 0xF1D98A) }
    static var mint: Color { Color(hex: 0xA8DCCB) }
    static var lavender: Color { Color(hex: 0xC9BFEA) }

    /// 敵の体の色（遠い＝sky、近い＝butter、城の前＝peach、届いた＝peach の淡い地）
    static func foeBody(_ stage: Stage) -> Color {
        switch stage {
        case .far: return sky
        case .near: return butter
        case .gate: return peach
        case .breached: return peachSoft
        }
    }

    static func foeOutline(_ stage: Stage) -> Color {
        stage >= .gate ? peachDeep : skyDeep
    }

    // 書体：見出しと数字はセリフ、本文はサンセリフ
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func sans(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    // 角丸
    static let radiusS: CGFloat = 6
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 18

    // 影（弱い・浮いた物）
    static var shadowSoft: Color { Color(hex: 0x2E3A46, opacity: 0.07) }
    static var shadowFloat: Color { Color(hex: 0x2E3A46, opacity: 0.16) }
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
        case .meadow: return Color(hex: 0xEAF2EA)
        case .harbor: return Color(hex: 0xE4EEF6)
        case .snow: return Color(hex: 0xF1F2F8)
        case .dusk: return Color(hex: 0xF6ECE8)
        }
    }

    var road: Color {
        switch self {
        case .meadow: return Color(hex: 0xEFE5D8)
        case .harbor: return Color(hex: 0xF1E8D9)
        case .snow: return Color(hex: 0xE3E5EF)
        case .dusk: return Color(hex: 0xEBDDD6)
        }
    }

    /// 地面の小さな模様（草・波・雪・星）
    var speck: Color {
        switch self {
        case .meadow: return Color(hex: 0xA8DCCB)
        case .harbor: return Color(hex: 0x9EC3E2)
        case .snow: return Color(hex: 0xC9BFEA)
        case .dusk: return Color(hex: 0xF4BBA4)
        }
    }
}
