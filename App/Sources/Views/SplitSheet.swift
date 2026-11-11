import SwiftUI

/// 大きい敵を小さく分ける（先延ばし対策「小さく分ける」を、遊びの得にする）
struct SplitSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let foe: Foe
    @State private var steps: [String] = []
    @State private var templateID: String?

    var body: some View {
        let ja = Content.isJapanese
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 分ける前と後の絵
                    HStack(spacing: 14) {
                        FoeFigure(weight: foe.weight, stage: model.stage(of: foe), progress: model.progress(of: foe))
                            .scaleEffect(1.3)
                            .frame(width: 60, height: 60)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                        HStack(spacing: 2) {
                            ForEach(0..<max(2, filledCount), id: \.self) { _ in
                                FoeFigure(weight: 1, stage: model.stage(of: foe), progress: model.progress(of: foe))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(foe.title)
                            .font(Theme.serif(20, .medium))
                            .foregroundStyle(Theme.ink)
                        Text("小さい敵は1回で倒れます。締め切りは同じまま。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                    }

                    VStack(spacing: 8) {
                        ForEach(steps.indices, id: \.self) { index in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(Theme.serif(14))
                                    .foregroundStyle(Theme.skyDeep)
                                    .frame(width: 22)
                                TextField("小さな一歩", text: $steps[index])
                                    .font(.system(size: 15))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.line, lineWidth: 1))
                        }
                        if steps.count < 4 {
                            Button {
                                model.select()
                                steps.append("")
                            } label: {
                                Label("一歩を足す", systemImage: "plus")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.skyDeep)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("分け方の型")
                            .font(Theme.serif(15, .medium))
                            .foregroundStyle(Theme.ink)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                            ForEach(Content.templates) { template in
                                templateButton(template, ja: ja)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle(Text("分ける"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("分ける") {
                        model.split(foe, into: steps)
                        dismiss()
                    }
                    .disabled(filledCount < 2)
                    .accessibilityIdentifier("main.confirmSplit")
                }
            }
        }
        .tint(Theme.skyDeep)
        .onAppear(perform: prepare)
    }

    private var filledCount: Int {
        steps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private func prepare() {
        guard steps.isEmpty else { return }
        let ja = Content.isJapanese
        if let template = Content.suggestedTemplate(for: foe.title, includePro: model.isPro) {
            templateID = template.id
            steps = template.steps.map { $0.text(japanese: ja) }
        } else {
            steps = Content.fallbackSteps.map { $0.text(japanese: ja) }
        }
    }

    private func templateButton(_ template: SplitTemplate, ja: Bool) -> some View {
        let locked = !template.isFree && !model.isPro
        let selected = templateID == template.id
        return Button {
            model.select()
            if locked {
                model.activeSheet = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    model.activeSheet = .paywall(.template)
                }
                return
            }
            templateID = template.id
            steps = template.steps.map { $0.text(japanese: ja) }
        } label: {
            HStack(spacing: 6) {
                Text(template.name.text(japanese: ja))
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(locked ? Theme.sub : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.sub)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).fill(selected ? Theme.skySoft : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(selected ? Theme.sky : Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}
