import SwiftUI

/// 戦場：地図＋次に倒す 1 体＋1 行の追加＋今日の波（縦のタイムライン）。
/// 広い画面（iPhone Duo の内側など、regular）では左に地図、右に一覧。並べ方は size class で決める。
struct FieldView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var focusID: UUID?

    var body: some View {
        ZStack(alignment: .top) {
            WoodTable()
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
                        .padding(14)
                        .parchmentCard(radius: Theme.radiusL, fill: Theme.paper)
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
                        VStack(spacing: 14) {
                            NextTargetCard(foe: focused, onSplit: openSplit)
                            AddBar()
                            WaveList(focusID: $focusID, onSplit: openSplit)
                        }
                        .padding(14)
                        .parchmentCard(radius: Theme.radiusL, fill: Theme.paper)
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
            VStack(alignment: .leading, spacing: 6) {
                GameTitle(text: "しめきりディフェンス", size: 24)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    StatToken(systemName: "shield.lefthalf.filled", text: "城 Lv.\(model.chronicle.castleLevel)", color: Theme.skyDeep)
                    StatToken(systemName: "flame.fill", text: "守った日 \(model.chronicle.streak(now: model.now))", color: Theme.peach)
                }
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
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(ChunkyFill(shape: Circle(), color: Theme.gold, edge: Theme.goldDeep))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(label))
    }
}

/// 押すとコマが盤に沈む（下へ 2pt・0.96 倍）
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 木の上の小さな札（城のレベル・守った日）
struct StatToken: View {
    let systemName: String
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.cream)
                .frame(width: 18, height: 18)
                .background(Circle().fill(color).overlay(Circle().stroke(Theme.woodGrain, lineWidth: 1)))
            Text(text)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.cream)
                .lineLimit(1)
        }
        .padding(.leading, 3)
        .padding(.trailing, 9)
        .frame(height: 24)
        .background(Capsule().fill(Theme.woodDeep.opacity(0.85)).overlay(Capsule().stroke(Theme.woodGrain, lineWidth: 1)))
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
        .parchmentCard()
    }

    private func content(_ foe: Foe) -> some View {
        let stage = model.stage(of: foe)
        return HStack(alignment: .center, spacing: 14) {
            FoeFigure(weight: foe.weight, stage: stage, progress: model.progress(of: foe), highlighted: true)
                .scaleEffect(1.4)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(stage == .breached ? LocalizedStringKey("城に届いた敵") : LocalizedStringKey("次に倒す1体"))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.cream)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(stage >= .gate ? Theme.peachDeep : Theme.wood))
                Text(foe.title)
                    .font(Theme.display(18, .medium))
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
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(ChunkyFill(shape: Capsule()))
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
                    .font(Theme.display(17, .medium))
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(ChunkyFill(shape: Capsule(), color: Theme.skySoft, edge: Theme.line))
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
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.peachDeep)
                Text(wave.isEmpty ? LocalizedStringKey("今日の締め切りはありません") : "今日、\(wave.count)体がやってきます")
                    .font(Theme.display(17, .medium))
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
        .parchmentCard(radius: Theme.radiusL)
        .shadow(color: Theme.shadowFloat, radius: 14, y: 6)
        .task {
            // 撮影では消さない
            guard Launch.scene == nil else { return }
            try? await Task.sleep(for: .seconds(6))
            model.dismissWaveBanner()
        }
    }
}
