import SwiftUI

/// 戦場：地図＋次に倒す 1 体＋1 行の追加＋今日の波（縦のタイムライン）。
/// 広い画面（iPhone Duo の内側など、regular）では左に地図、右に一覧。並べ方は size class で決める。
struct FieldView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var focusID: UUID?

    var body: some View {
        ZStack(alignment: .top) {
            Theme.paper.ignoresSafeArea()
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 12) {
                        header
                        map
                    }
                    .frame(maxWidth: .infinity)
                    ScrollView {
                        VStack(spacing: 14) {
                            NextTargetCard(foe: focused, onSplit: openSplit)
                            AddBar()
                            WaveList(focusID: $focusID, onSplit: openSplit)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: 420)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        map
                            .frame(height: 360)
                        NextTargetCard(foe: focused, onSplit: openSplit)
                        AddBar()
                        WaveList(focusID: $focusID, onSplit: openSplit)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            if model.showWaveBanner {
                WaveBanner()
                    .padding(.horizontal, 16)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.showWaveBanner)
    }

    private var focused: Foe? {
        if let focusID, let foe = model.active.first(where: { $0.id == focusID }) { return foe }
        return model.nextTarget
    }

    private var map: some View {
        MapView(
            focusID: focused?.id,
            onTapFoe: { foe in
                model.select()
                focusID = foe.id
            },
            onLongPressFoe: { foe in openSplit(foe) }
        )
        .frame(minHeight: 320)
        .accessibilityIdentifier("main.map")
    }

    private func openSplit(_ foe: Foe) {
        model.select()
        model.activeSheet = .split(foe)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("しめきりディフェンス")
                    .font(Theme.serif(20, .medium))
                    .kerning(-0.4)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Text("城 Lv.\(model.chronicle.castleLevel)")
                    Text("·")
                    Text("守った日 \(model.chronicle.streak(now: model.now))")
                }
                .font(.system(size: 11, weight: .medium))
                .kerning(0.6)
                .monospacedDigit()
                .foregroundStyle(Theme.sub)
            }
            Spacer()
            HeaderButton(systemName: "chart.bar.xaxis", label: "戦果") {
                model.select()
                model.activeSheet = .report
            }
            .accessibilityIdentifier("main.report")
            HeaderButton(systemName: "gearshape", label: "設定") {
                model.select()
                model.activeSheet = .settings
            }
            .accessibilityIdentifier("main.settings")
        }
        .padding(.top, 6)
    }
}

struct HeaderButton: View {
    let systemName: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.skyDeep)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.card).overlay(Circle().stroke(Theme.line, lineWidth: 1)))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(label))
    }
}

/// 押すと少し縮む（0.96 倍）。弾ませすぎない
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 次に倒す 1 体：大きな敵の絵と、倒した・分ける・明日に回す
struct NextTargetCard: View {
    @Environment(AppModel.self) private var model
    let foe: Foe?
    let onSplit: (Foe) -> Void

    var body: some View {
        Group {
            if let foe {
                content(foe)
            } else {
                empty
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private func content(_ foe: Foe) -> some View {
        let stage = model.stage(of: foe)
        return HStack(alignment: .center, spacing: 14) {
            FoeFigure(weight: foe.weight, stage: stage, progress: model.progress(of: foe), highlighted: true)
                .scaleEffect(1.4)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(stage == .breached ? LocalizedStringKey("城に届いた敵") : LocalizedStringKey("次に倒す1体"))
                    .font(.system(size: 10, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(stage >= .gate ? Theme.peachDeep : Theme.sub)
                Text(foe.title)
                    .font(Theme.serif(18, .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Text(RemainingText.key(deadline: foe.deadline, now: model.now))
                        .monospacedDigit()
                    Text("·")
                    Text(WeightLabel.key(foe.weight))
                    if foe.isSample {
                        Text("·")
                        Text("見本")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                HStack(spacing: 8) {
                    Button {
                        model.defeat(foe)
                    } label: {
                        Label("済ませた", systemImage: "scope")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Capsule().fill(Theme.skyDeep))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("main.defeat")
                    if foe.weight >= 2 {
                        SmallActionButton(title: "分ける", systemName: "scissors") { onSplit(foe) }
                            .accessibilityIdentifier("main.split")
                    }
                    if stage >= .gate {
                        SmallActionButton(title: "明日に回す", systemName: "arrow.uturn.backward") { model.deferToTomorrow(foe) }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    private var empty: some View {
        HStack(spacing: 14) {
            CastleFigure(health: model.castleHealth, level: model.chronicle.castleLevel)
                .frame(width: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text("道に敵はいません")
                    .font(Theme.serif(17, .medium))
                    .foregroundStyle(Theme.ink)
                Text("締め切りのある用事を1行で入れると、敵になって歩き始めます。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SmallActionButton: View {
    let title: LocalizedStringKey
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.skyDeep)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Capsule().fill(Theme.skySoft))
        }
        .buttonStyle(PressStyle())
    }
}

enum WeightLabel {
    static func key(_ weight: Int) -> LocalizedStringKey {
        switch weight {
        case 1: return "軽い"
        case 2: return "ふつう"
        default: return "重い"
        }
    }
}

/// 朝の「今日の波」：その日に初めて開いたとき、上からそっと出る
struct WaveBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let wave = model.todaysWave
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日の波")
                    .font(.system(size: 10, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Theme.sub)
                Text(wave.isEmpty ? LocalizedStringKey("今日の締め切りはありません") : "今日、\(wave.count)体がやってきます")
                    .font(Theme.serif(17, .medium))
                    .foregroundStyle(Theme.ink)
                Text(model.tactic.title.text(japanese: Content.isJapanese))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.skyDeep)
            }
            Spacer()
            HStack(spacing: -6) {
                ForEach(wave.prefix(4)) { foe in
                    FoeFigure(weight: foe.weight, stage: model.stage(of: foe), progress: model.progress(of: foe))
                        .scaleEffect(0.8)
                }
            }
            Button {
                model.dismissWaveBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.sub)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("閉じる"))
        }
        .padding(.leading, 14)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).fill(Theme.card).shadow(color: Theme.shadowFloat, radius: 14, y: 6))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .task {
            // 撮影では消さない
            guard Launch.scene == nil else { return }
            try? await Task.sleep(for: .seconds(6))
            model.dismissWaveBanner()
        }
    }
}
