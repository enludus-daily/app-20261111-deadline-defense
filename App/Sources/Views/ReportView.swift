import SwiftUI

/// 戦果：今日の 1 枚の絵（共有できる）・守った日・週のマス・Pro の 1 年の記録
struct ReportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    var body: some View {
        let chronicle = model.chronicle
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    BattleCard(
                        record: model.todayRecord,
                        health: model.castleHealth,
                        level: chronicle.castleLevel,
                        streak: chronicle.streak(now: model.now),
                        date: model.now,
                        theme: model.effectiveTheme
                    )
                    .frame(maxWidth: 380)
                    .frame(maxWidth: .infinity)

                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("今日の戦果", image: shareImage)) {
                            Label("戦果の絵を共有", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.skyDeep)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(Theme.skySoft))
                        }
                        .accessibilityIdentifier("main.share")
                    }

                    numbers(chronicle)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("守った日のマス")
                                .font(Theme.serif(16, .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(model.isPro ? LocalizedStringKey("52週") : LocalizedStringKey("4週"))
                                .font(.system(size: 11, weight: .medium))
                                .kerning(0.6)
                                .foregroundStyle(Theme.sub)
                        }
                        Heatmap(weeks: chronicle.weeks(model.isPro ? 52 : 4, now: model.now), compact: model.isPro)
                    }

                    proSection(chronicle)
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationTitle(Text("戦果"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(Theme.skyDeep)
        .task { renderShareImage() }
    }

    private func numbers(_ chronicle: Chronicle) -> some View {
        HStack(spacing: 0) {
            BigNumber(value: chronicle.streak(now: model.now), label: "守った日")
            Divider().frame(height: 44)
            BigNumber(value: chronicle.totalDefeated, label: "倒した敵")
            Divider().frame(height: 44)
            BigNumber(value: chronicle.splitDefeated, label: "分けて倒した")
        }
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    @ViewBuilder
    private func proSection(_ chronicle: Chronicle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("くわしい戦いの記録")
                .font(Theme.serif(16, .medium))
                .foregroundStyle(Theme.ink)
            if model.isPro {
                VStack(spacing: 0) {
                    StatRow(label: "締め切りまでに倒した割合", value: chronicle.onTimeRate.map { Text($0, format: .percent.precision(.fractionLength(0))) } ?? Text("—"))
                    StatRow(label: "よく倒す時間", value: chronicle.bestHour.map { Text("\($0)時台") } ?? Text("—"))
                    StatRow(label: "これまでの点", value: Text("\(model.points)"))
                    StatRow(label: "城のレベル", value: Text("Lv.\(chronicle.castleLevel)"), last: true)
                }
                .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
            } else {
                Button {
                    model.activeSheet = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        model.activeSheet = .paywall(.history)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .foregroundStyle(Theme.skyDeep)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("1年のマス・期限内に倒した割合・よく倒す時間")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Text("Pro で見られます")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.sub)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("main.proHistory")
            }
        }
    }

    private func renderShareImage() {
        let chronicle = model.chronicle
        let card = BattleCard(
            record: model.todayRecord,
            health: model.castleHealth,
            level: chronicle.castleLevel,
            streak: chronicle.streak(now: model.now),
            date: model.now,
            theme: model.effectiveTheme
        )
        .frame(width: 360)
        .padding(18)
        .background(Theme.paper)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareImage = Image(uiImage: image)
        }
    }
}

struct BigNumber: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(Theme.serif(30, .regular))
                .kerning(-1.5)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatRow: View {
    let label: LocalizedStringKey
    let value: Text
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                Spacer()
                value
                    .font(Theme.serif(16))
                    .monospacedDigit()
                    .foregroundStyle(Theme.skyDeep)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            if !last { Divider().padding(.leading, 14) }
        }
    }
}

/// 今日の戦いの 1 枚の絵（Pokémon Sleep の「結果発表」にならい、1 日の終わりに見る）
struct BattleCard: View {
    let record: DayRecord
    let health: Int
    let level: Int
    let streak: Int
    let date: Date
    let theme: MapTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(date, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
                    .font(.system(size: 11, weight: .medium))
                    .kerning(0.6)
                    .foregroundStyle(Theme.sub)
                Spacer()
                Text("しめきりディフェンス")
                    .font(Theme.serif(11))
                    .foregroundStyle(Theme.sub)
            }
            HStack(alignment: .bottom, spacing: 6) {
                Text("\(record.defeated)")
                    .font(Theme.serif(64, .regular))
                    .kerning(-3)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("体を倒した")
                    .font(Theme.serif(16))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 12)
            }
            // 倒した敵が城の前に並ぶ絵
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .fill(theme.ground)
                Capsule().fill(theme.road).frame(height: 18).padding(.horizontal, 12).padding(.bottom, 22)
                HStack(alignment: .bottom, spacing: 12) {
                    HStack(spacing: -4) {
                        ForEach(0..<min(record.defeated, 7), id: \.self) { i in
                            FoeFigure(weight: 1 + i % 3, stage: .far, progress: 1)
                                .opacity(0.5)
                                .rotationEffect(.degrees(i % 2 == 0 ? -8 : 6))
                        }
                    }
                    Spacer(minLength: 0)
                    CastleFigure(health: health, level: level)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .frame(height: 120)
            HStack(spacing: 16) {
                cardStat(value: record.points, label: "点")
                cardStat(value: health, label: "城の守り")
                cardStat(value: streak, label: "守った日")
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous).fill(Theme.card).shadow(color: Theme.shadowSoft, radius: 12, y: 4))
        .overlay(alignment: .topLeading) {
            TapeShape()
                .fill(Theme.tape.opacity(0.85))
                .frame(width: 78, height: 20)
                .rotationEffect(.degrees(-4))
                .offset(x: 24, y: -9)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func cardStat(value: Int, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(Theme.serif(20))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(Theme.sub)
        }
    }
}

/// 守った日のマス（StudyReel のヒートマップ：マス 9〜16pt・間隔 2〜3・濃さ 5 段階）
struct Heatmap: View {
    let weeks: [[DayRecord]]
    var compact = false

    var body: some View {
        let cell: CGFloat = compact ? 9 : 22
        let gap: CGFloat = compact ? 2 : 4
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: gap) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: gap) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            RoundedRectangle(cornerRadius: compact ? 2 : 5, style: .continuous)
                                .fill(Self.color(day.level))
                                .overlay {
                                    if day.breaches > 0 && !compact {
                                        Circle().fill(Theme.peach).frame(width: 4, height: 4)
                                    }
                                }
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .padding(2)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
        .accessibilityElement()
        .accessibilityLabel(Text("守った日のマス"))
    }

    static func color(_ level: Int) -> Color {
        switch level {
        case 0: return Theme.line
        case 1: return Theme.skySoft
        case 2: return Theme.sky.opacity(0.6)
        case 3: return Theme.sky
        default: return Theme.skyDeep
        }
    }
}
