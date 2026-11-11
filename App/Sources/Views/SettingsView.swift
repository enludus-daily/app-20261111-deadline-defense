import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("音と振動") {
                        ToggleRow(title: "効果音", isOn: $model.soundOn)
                        ToggleRow(title: "振動", isOn: $model.hapticsOn, last: true)
                    }

                    group("お知らせ") {
                        ToggleRow(title: "締め切りの少し前に知らせる", isOn: Binding(
                            get: { model.remindersOn },
                            set: { value in Task { await model.setReminders(value) } }
                        ), last: !model.remindersDenied)
                        if model.remindersDenied {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("お知らせが許可されていません。設定アプリで「通知」をオンにすると届きます。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.sub)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("設定を開く") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.skyDeep)
                            }
                            .padding(14)
                        }
                    }

                    group("地図") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(MapTheme.allCases) { theme in
                                    ThemeSwatch(theme: theme, selected: model.effectiveTheme == theme, locked: theme.isPro && !model.isPro) {
                                        model.select()
                                        if theme.isPro && !model.requirePro(.theme) { return }
                                        model.mapTheme = theme
                                    }
                                }
                            }
                            .padding(14)
                        }
                        .scrollIndicators(.hidden)
                    }

                    group("砲台") {
                        ForEach(TowerKind.allCases) { kind in
                            TowerRow(kind: kind, selected: model.effectiveTower == kind, locked: kind.isPro && !model.isPro, last: kind == TowerKind.allCases.last) {
                                model.select()
                                if kind.isPro && !model.requirePro(.tower) { return }
                                model.tower = kind
                            }
                        }
                    }

                    group("Pro") {
                        if model.isPro {
                            InfoRow(title: "Pro を使っています", detail: "ありがとうございます。すべての地図・砲台・型・1年の記録が使えます。", last: true)
                        } else {
                            ActionRow(title: "Pro でできること", systemName: "sparkles") {
                                model.activeSheet = .paywall(.settings)
                            }
                            .accessibilityIdentifier("main.openPaywall")
                        }
                        if !model.isPro {
                            ActionRow(title: "購入を復元", systemName: "arrow.clockwise", last: true) {
                                Task { await model.purchases.restore() }
                            }
                        }
                    }

                    group("使い方") {
                        ActionRow(title: "使い方をもう一度見る", systemName: "book") {
                            model.onboarded = false
                            dismiss()
                        }
                        ActionRow(title: "見本の敵を出す", systemName: "figure.walk", last: true) {
                            model.restoreSamples()
                            dismiss()
                        }
                    }

                    group("プライバシー") {
                        InfoRow(title: "データは端末の中だけ", detail: "用事・締め切り・戦果はこの iPhone の中にだけ保存します。外に送らず、アカウントもありません。", last: true)
                    }

                    Text("バージョン \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationTitle(Text("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(Theme.skyDeep)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func group<Inner: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Inner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(Theme.sub)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }
}

struct ToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isOn) {
                Text(title).font(.system(size: 14)).foregroundStyle(Theme.ink)
            }
            .tint(Theme.skyDeep)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            if !last { Divider().padding(.leading, 14) }
        }
    }
}

struct ActionRow: View {
    let title: LocalizedStringKey
    let systemName: String
    var last = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: systemName)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.skyDeep)
                        .frame(width: 22)
                    Text(title).font(.system(size: 14)).foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.sub)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !last { Divider().padding(.leading, 48) }
        }
    }
}

struct InfoRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var last = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
            Text(detail).font(.system(size: 12)).foregroundStyle(Theme.sub).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ThemeSwatch: View {
    let theme: MapTheme
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                MiniMap(theme: theme)
                    .frame(width: 84, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(selected ? Theme.skyDeep : Theme.line, lineWidth: selected ? 1.5 : 1))
                    .overlay(alignment: .topTrailing) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.sub)
                                .padding(6)
                        }
                    }
                Text(theme.name)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 小さな地図の見本（設定と課金の画面で、テーマを実物で見比べる）
struct MiniMap: View {
    let theme: MapTheme

    var body: some View {
        GeometryReader { proxy in
            let path = MarchPath(size: proxy.size, samples: 60)
            ZStack {
                theme.ground
                Canvas { context, _ in
                    var line = Path()
                    line.addLines(path.points)
                    context.stroke(line, with: .color(theme.road), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                }
                ForEach(Array([0.2, 0.55, 0.8].enumerated()), id: \.offset) { index, t in
                    FoeFigure(weight: 1, stage: index == 2 ? .gate : (index == 1 ? .near : .far), progress: t)
                        .scaleEffect(0.55)
                        .position(path.point(at: t))
                }
                CastleShape()
                    .fill(Theme.card)
                    .overlay(CastleShape().stroke(Theme.skyDeep.opacity(0.8), lineWidth: 0.8))
                    .frame(width: 26, height: 17)
                    .position(x: proxy.size.width * MarchPath.castleSpot.x, y: proxy.size.height * MarchPath.castleSpot.y - 4)
            }
        }
        .accessibilityHidden(true)
    }
}

struct TowerRow: View {
    let kind: TowerKind
    let selected: Bool
    let locked: Bool
    let last: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    TowerFigure(kind: kind)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.name(kind)).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                        Text(Self.detail(kind)).font(.system(size: 12)).foregroundStyle(Theme.sub).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if locked {
                        Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(Theme.sub)
                    } else if selected {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.skyDeep)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !last { Divider().padding(.leading, 56) }
        }
    }

    static func name(_ kind: TowerKind) -> LocalizedStringKey {
        switch kind {
        case .basic: return "見張りの砲台"
        case .morning: return "朝の砲台"
        case .rapid: return "連射台"
        }
    }

    static func detail(_ kind: TowerKind) -> LocalizedStringKey {
        switch kind {
        case .basic: return "済ませるたびに1発。いつでも使える"
        case .morning: return "正午までに倒すと点が2倍"
        case .rapid: return "連続が30分続く（ふつうは10分）"
        }
    }
}
