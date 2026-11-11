import SwiftUI

/// 今日の波と、その先の敵。Structured のように時刻の付いた縦の 1 本の線に並べる
struct WaveList: View {
    @Environment(AppModel.self) private var model
    @Binding var focusID: UUID?
    let onSplit: (Foe) -> Void

    var body: some View {
        let wave = model.todaysWave
        let later = model.active.filter { foe in !wave.contains(where: { $0.id == foe.id }) }
        let defeated = model.field.defeated(on: model.now, calendar: model.calendar)
            .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }

        VStack(alignment: .leading, spacing: 16) {
            if model.hasSamples {
                SampleNotice()
            }
            section(title: "今日の波", count: wave.count) {
                if wave.isEmpty {
                    EmptyLine(text: "今日の締め切りはありません。先の敵を倒しておくと、早めの得点が付きます。")
                } else {
                    timeline(wave)
                }
            }
            if !later.isEmpty {
                section(title: "その先", count: later.count) {
                    timeline(later)
                }
            }
            if !defeated.isEmpty {
                section(title: "今日倒した", count: defeated.count) {
                    VStack(spacing: 0) {
                        ForEach(defeated) { foe in
                            DefeatedRow(foe: foe)
                        }
                    }
                }
            }
            TacticCard(tactic: model.tactic)
        }
    }

    private func section<Inner: View>(title: LocalizedStringKey, count: Int, @ViewBuilder content: () -> Inner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(Theme.serif(16, .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(count)")
                    .font(Theme.serif(13))
                    .monospacedDigit()
                    .foregroundStyle(Theme.sub)
            }
            content()
        }
    }

    private func timeline(_ foes: [Foe]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(foes.enumerated()), id: \.element.id) { index, foe in
                FoeRow(foe: foe, isLast: index == foes.count - 1, focused: foe.id == focusID) {
                    model.select()
                    focusID = foe.id
                } onSplit: {
                    onSplit(foe)
                }
            }
        }
    }
}

struct FoeRow: View {
    @Environment(AppModel.self) private var model
    let foe: Foe
    let isLast: Bool
    let focused: Bool
    let onFocus: () -> Void
    let onSplit: () -> Void

    var body: some View {
        let stage = model.stage(of: foe)
        HStack(alignment: .top, spacing: 12) {
            // 時刻
            Text(foe.deadline, format: Self.timeFormat(foe.deadline, now: model.now, calendar: model.calendar))
                .font(Theme.serif(13))
                .monospacedDigit()
                .foregroundStyle(stage >= .gate ? Theme.peachDeep : Theme.sub)
                .frame(width: 54, alignment: .trailing)
                .padding(.top, 13)
            // 線と敵
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: 1)
                    .padding(.bottom, isLast ? 30 : 0)
                FoeFigure(weight: foe.weight, stage: stage, progress: model.progress(of: foe), highlighted: focused)
                    .padding(.top, 4)
            }
            .frame(width: 50)
            // 名前と操作
            VStack(alignment: .leading, spacing: 3) {
                Text(foe.title)
                    .font(.system(size: 15, weight: focused ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(RemainingText.key(deadline: foe.deadline, now: model.now))
                    if let parent = foe.splitFrom {
                        Text("· \(parent)から")
                            .lineLimit(1)
                    }
                    if foe.deferrals > 0 {
                        Text("· 回した \(foe.deferrals)")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.sub)
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onFocus)

            Button {
                model.defeat(foe)
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.skyDeep)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.skySoft))
            }
            .buttonStyle(PressStyle())
            .padding(.top, 2)
            .accessibilityLabel(Text("済ませた"))
        }
        .frame(minHeight: 62, alignment: .top)
        .contextMenu {
            Button { model.defeat(foe) } label: { Label("済ませた", systemImage: "scope") }
            Button(action: onSplit) { Label("分ける", systemImage: "scissors") }
            Button { model.deferToTomorrow(foe) } label: { Label("明日の波に回す", systemImage: "arrow.uturn.backward") }
            Button(role: .destructive) { model.remove(foe) } label: { Label("消す", systemImage: "trash") }
        }
    }

    static func timeFormat(_ date: Date, now: Date, calendar: Calendar) -> Date.FormatStyle {
        if calendar.isDate(date, inSameDayAs: now) {
            return .dateTime.hour().minute()
        }
        return .dateTime.month(.defaultDigits).day()
    }
}

struct DefeatedRow: View {
    @Environment(AppModel.self) private var model
    let foe: Foe

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.skyDeep)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.skySoft))
            Text(foe.title)
                .font(.system(size: 14))
                .strikethrough(true, color: Theme.sub)
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
            Spacer()
            Button("戻す") { model.undo(foe) }
                .font(.system(size: 12))
                .foregroundStyle(Theme.skyDeep)
                .frame(minWidth: 44, minHeight: 36)
        }
        .padding(.vertical, 2)
    }
}

struct EmptyLine: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.sub)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
    }
}

/// 見本の敵がいるときの案内（最初の 10 秒）
struct SampleNotice: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TapeShape()
                .fill(Theme.tape.opacity(0.85))
                .frame(width: 36, height: 14)
                .rotationEffect(.degrees(-4))
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("いま道を歩いているのは見本の敵です")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("◎ を押すと砲台が撃ちます。長押しで分けられます。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                Button("見本を片づけて、自分の用事を入れる") { model.clearSamples() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.skyDeep)
                    .padding(.top, 2)
                    .accessibilityIdentifier("main.clearSamples")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.skyPaper))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// 今日の作戦（42 の作戦から日替わり）
struct TacticCard: View {
    let tactic: Tactic

    var body: some View {
        let ja = Content.isJapanese
        VStack(alignment: .leading, spacing: 4) {
            Text("今日の作戦")
                .font(.system(size: 10, weight: .medium))
                .kerning(0.6)
                .foregroundStyle(Theme.sub)
            Text(tactic.title.text(japanese: ja))
                .font(Theme.serif(16, .medium))
                .foregroundStyle(Theme.ink)
            Text(tactic.detail.text(japanese: ja))
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.peachSoft.opacity(0.55)))
    }
}
