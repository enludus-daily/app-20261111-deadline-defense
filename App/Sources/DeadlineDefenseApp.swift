import SwiftUI

@main
struct DeadlineDefenseApp: App {
    @State private var model = Launch.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    @State var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if model.onboarded {
                FieldView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(model)
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet) { sheet in
            sheetView(sheet)
                .environment(model)
                .preferredColorScheme(.light)
        }
        .sensoryFeedback(trigger: model.selectTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.defeatTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: model.comboTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.breachTick) { _, _ in model.hapticsOn ? .warning : nil }
        .sensoryFeedback(trigger: model.clearTick) { _, _ in model.hapticsOn ? .success : nil }
        .task {
            await Launch.run(model)
        }
        .task {
            await model.purchases.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.tick()
                if Launch.scene == nil && !Launch.isDemo { model.openDay() }
            }
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .report: ReportView()
        case .settings: SettingsView()
        case .paywall(let reason): PaywallView(reason: reason)
        case .split(let foe): SplitSheet(foe: foe)
        }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない。
@MainActor
enum Launch {
    static var scene: String? {
        let value = UserDefaults.standard.string(forKey: "screenshotScene")
        return (value?.isEmpty ?? true) || value == "launch" ? nil : value
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static func makeModel() -> AppModel {
        if isDemo || scene != nil {
            let now = Date()
            let model = AppModel(persists: false, now: now, seed: Samples.foes(now: now, calendar: .current))
            model.onboarded = scene != "onboarding"
            if scene == "empty" { model.clearSamples() }
            if scene == "report" || scene == "pro" || scene == "clear" || isDemo { model.seedHistory() }
            if scene == "pro" { model.proOverride = true }
            return model
        }
        let model = AppModel()
        model.seedSamplesIfFirstLaunch()
        return model
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else {
            // ふつうの起動：30 秒ごとに敵を進める
            while !Task.isCancelled {
                model.tick()
                try? await Task.sleep(for: .seconds(30))
            }
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        switch scene {
        case "wave":
            model.presentWaveBanner()
        case "split":
            if let heavy = model.active.first(where: { $0.weight == 3 }) { model.activeSheet = .split(heavy) }
        case "report", "pro":
            model.activeSheet = .report
        case "settings":
            model.activeSheet = .settings
        case "paywall":
            model.activeSheet = .paywall(.cleared)
        case "clear":
            // 今日の波を全部倒した直後
            for foe in model.todaysWave { model.defeat(foe) }
        case "shot":
            // 砲台が撃った瞬間
            if let foe = model.nextTarget { model.defeat(foe) }
        default:
            break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 20 秒）
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        let ja = Content.isJapanese
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }

        await wait(1.2)
        model.say(.hello)
        await wait(1.0)
        // 1 行で追加すると、重い敵が道に出る
        let proposal = model.add(
            title: ja ? "企画書を出す" : "Send the proposal",
            deadline: DeadlineChip.tonight.deadline(from: model.now, calendar: model.calendar),
            weight: 3
        )
        await wait(1.8)
        // 城の前の敵から倒す（砲台が撃つ）
        if let first = model.active.first(where: { $0.id != proposal?.id }) { model.defeat(first) }
        await wait(1.4)
        if let second = model.active.first(where: { $0.id != proposal?.id }) { model.defeat(second) }
        await wait(1.6)
        // 重い敵を分ける
        if let proposal, let foe = model.active.first(where: { $0.id == proposal.id }) {
            model.activeSheet = .split(foe)
            await wait(2.4)
            model.activeSheet = nil
            await wait(0.4)
            model.split(foe, into: Content.fallbackSteps.map { $0.text(japanese: ja) })
        }
        await wait(1.4)
        // 小さくなった敵を続けて倒す（連続）
        for _ in 0..<3 {
            if let next = model.active.first(where: { $0.splitFrom != nil }) { model.defeat(next) }
            await wait(0.9)
        }
        await wait(1.6)
        // 今日の戦果
        model.activeSheet = .report
    }
}
