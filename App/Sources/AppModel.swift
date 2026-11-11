import Foundation
import Observation
import SwiftUI

/// 画面の動き・振動・音のきっかけ（地図がこれを見て、砲台を撃つ・揺らす）
struct BattleEvent: Equatable, Identifiable {
    enum Kind: Equatable {
        case defeat(foe: Foe, progress: Double, combo: Int, points: Int)
        case breach(count: Int)
        case clear
        case spawn(Foe)
        case split(count: Int)
    }

    let id = UUID()
    let kind: Kind
}

/// 城の上の一言（Finch のやさしい反応にならう。責めない）
enum Speech: Equatable {
    case hello, thanks, combo(Int), cleared, deferred, breached, split, sample

    var text: LocalizedStringKey {
        switch self {
        case .hello: return "今日も城を守ろう"
        case .thanks: return "助かった！"
        case .combo(let n): return "\(n)連続！ その調子"
        case .cleared: return "今日の波を守りきった！"
        case .deferred: return "明日の波でまた会おう"
        case .breached: return "少し届いたけど、大丈夫"
        case .split: return "小さくなった。倒しやすい！"
        case .sample: return "見本の敵です。倒してみて"
        }
    }
}

enum PaywallReason: String, Identifiable {
    case cleared, theme, tower, template, history, settings
    var id: String { rawValue }
}

enum ActiveSheet: Identifiable, Equatable {
    case report, settings, paywall(PaywallReason), split(Foe)

    var id: String {
        switch self {
        case .report: return "report"
        case .settings: return "settings"
        case .paywall(let reason): return "paywall-\(reason.rawValue)"
        case .split(let foe): return "split-\(foe.id)"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var field: Battlefield
    var now: Date
    let calendar: Calendar

    // 設定（UserDefaults。PrivacyInfo.xcprivacy に CA92.1 で申告済み）
    var soundOn: Bool { didSet { save(); sound.isEnabled = soundOn } }
    var hapticsOn: Bool { didSet { save() } }
    private(set) var remindersOn: Bool
    private(set) var remindersDenied = false
    var mapTheme: MapTheme { didSet { save() } }
    var tower: TowerKind { didSet { save() } }
    var onboarded: Bool { didSet { save() } }

    // 画面の状態
    var activeSheet: ActiveSheet?
    private(set) var lastEvent: BattleEvent?
    private(set) var speech: Speech = .hello
    private(set) var speechTick = 0
    private(set) var points = 0
    private(set) var lastPaywallDay: String
    private(set) var showWaveBanner = false

    // 振動のきっかけ
    private(set) var selectTick = 0
    private(set) var defeatTick = 0
    private(set) var comboTick = 0
    private(set) var breachTick = 0
    private(set) var clearTick = 0

    let purchases: PurchaseStore
    let sound = SoundBoard()
    /// 撮影・デモで Pro の画面を見せる
    var proOverride = false
    let persists: Bool
    private let defaults: UserDefaults

    static let foesKey = "foes.v1"

    init(persists: Bool = true, defaults: UserDefaults = .standard, now: Date = Date(), calendar: Calendar = .current, seed: [Foe]? = nil) {
        self.persists = persists
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        let stored: [Foe]? = persists ? defaults.data(forKey: Self.foesKey).flatMap { try? JSONDecoder().decode([Foe].self, from: $0) } : nil
        field = Battlefield(foes: seed ?? stored ?? [])
        soundOn = persists ? (defaults.object(forKey: "soundOn") as? Bool ?? true) : true
        hapticsOn = persists ? (defaults.object(forKey: "hapticsOn") as? Bool ?? true) : true
        remindersOn = persists ? defaults.bool(forKey: "remindersOn") : false
        mapTheme = persists ? MapTheme(rawValue: defaults.string(forKey: "mapTheme") ?? "") ?? .meadow : .meadow
        tower = persists ? TowerKind(rawValue: defaults.string(forKey: "tower") ?? "") ?? .basic : .basic
        onboarded = persists ? defaults.bool(forKey: "onboarded") : true
        lastPaywallDay = persists ? defaults.string(forKey: "lastPaywallDay") ?? "" : ""
        points = persists ? defaults.integer(forKey: "points") : 0
        let bundle = Bundle.main.bundleIdentifier ?? "com.enludus.daily.007"
        let pro = ProductID.pro(bundleID: bundle)
        purchases = PurchaseStore(productIDs: [pro], proProductIDs: [pro])
        sound.isEnabled = soundOn
    }

    var isPro: Bool { proOverride || purchases.entitlements.isPro }

    // MARK: - 読み取り

    var active: [Foe] { field.active }
    var nextTarget: Foe? { field.nextTarget }
    var todaysWave: [Foe] { field.todaysWave(now: now, calendar: calendar) }
    var castleHealth: Int { field.castleHealth(on: now, calendar: calendar) }
    var chronicle: Chronicle { Chronicle(foes: field.foes, calendar: calendar) }
    var hasSamples: Bool { field.foes.contains(where: \.isSample) }
    var todayRecord: DayRecord { chronicle.record(for: now) }
    var tactic: Tactic { Content.tactic(for: now, calendar: calendar) }
    var effectiveTheme: MapTheme { mapTheme.isPro && !isPro ? .meadow : mapTheme }
    var effectiveTower: TowerKind { tower.isPro && !isPro ? .basic : tower }

    func progress(of foe: Foe) -> Double { Battlefield.progress(deadline: foe.deadline, now: now) }
    func stage(of foe: Foe) -> Stage { Battlefield.stage(deadline: foe.deadline, now: now) }

    // MARK: - 操作

    func tick(_ date: Date = Date()) {
        now = date
        let hit = field.registerBreaches(now: now)
        if !hit.isEmpty {
            breachTick += 1
            say(.breached)
            sound.play(.breach)
            lastEvent = BattleEvent(kind: .breach(count: hit.count))
            save()
        }
    }

    func select() {
        selectTick += 1
        sound.play(.tap)
    }

    @discardableResult
    func add(title: String, deadline: Date, weight: Int) -> Foe? {
        guard let foe = field.add(title: title, deadline: deadline, weight: weight, now: now) else { return nil }
        lastEvent = BattleEvent(kind: .spawn(foe))
        selectTick += 1
        sound.play(.wave)
        save()
        return foe
    }

    func defeat(_ foe: Foe) {
        let progress = self.progress(of: foe)
        guard let reward = field.defeat(foe.id, now: now, calendar: calendar, tower: effectiveTower) else { return }
        points += reward.points
        lastEvent = BattleEvent(kind: .defeat(foe: foe, progress: progress, combo: reward.combo, points: reward.points))
        if reward.combo > 1 {
            comboTick += 1
            say(.combo(reward.combo))
            sound.play(.combo, combo: reward.combo)
        } else {
            defeatTick += 1
            say(foe.isSample ? .sample : .thanks)
            sound.play(.defeat)
        }
        if reward.clearedWave {
            clearTick += 1
            say(.cleared)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                self?.sound.play(.clear)
                self?.lastEvent = BattleEvent(kind: .clear)
                self?.offerPaywallAfterClear()
            }
        }
        save()
    }

    func undo(_ foe: Foe) {
        field.revive(foe.id)
        save()
    }

    func split(_ foe: Foe, into titles: [String]) {
        let parts = field.split(foe.id, into: titles, now: now)
        guard !parts.isEmpty else { return }
        lastEvent = BattleEvent(kind: .split(count: parts.count))
        selectTick += 1
        say(.split)
        sound.play(.wave)
        save()
    }

    func deferToTomorrow(_ foe: Foe) {
        field.deferToTomorrow(foe.id, now: now, calendar: calendar)
        selectTick += 1
        say(.deferred)
        save()
    }

    func remove(_ foe: Foe) {
        field.remove(foe.id)
        save()
    }

    func clearSamples() {
        field.removeSamples()
        selectTick += 1
        save()
    }

    func restoreSamples() {
        field.removeSamples()
        field.foes.append(contentsOf: Samples.foes(now: now, calendar: calendar))
        save()
    }

    func say(_ line: Speech) {
        speech = line
        speechTick += 1
    }

    // MARK: - 今日の波

    /// その日に初めて開いたとき、今日の波を知らせる
    func openDay() {
        let key = Self.dayKey(now, calendar: calendar)
        guard persists, defaults.string(forKey: "waveBannerDay") != key else { return }
        defaults.set(key, forKey: "waveBannerDay")
        showWaveBanner = true
        sound.play(.wave)
    }

    func dismissWaveBanner() { showWaveBanner = false }

    func presentWaveBanner() { showWaveBanner = true }

    // MARK: - お知らせ

    func setReminders(_ on: Bool) async {
        if on {
            let granted = await Reminders.requestAuthorization()
            remindersOn = granted
            remindersDenied = !granted
        } else {
            remindersOn = false
        }
        save()
    }

    // MARK: - 課金の画面（価値を感じた直後だけ。1 日 1 回まで）

    private func offerPaywallAfterClear() {
        guard !isPro, persists, activeSheet == nil else { return }
        let key = Self.dayKey(now, calendar: calendar)
        guard lastPaywallDay != key, chronicle.totalDefeated >= 3 else { return }
        lastPaywallDay = key
        save()
        activeSheet = .paywall(.cleared)
    }

    func requirePro(_ reason: PaywallReason) -> Bool {
        if isPro { return true }
        activeSheet = .paywall(reason)
        return false
    }

    // MARK: - 保存

    private func save() {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(field.foes) { defaults.set(data, forKey: Self.foesKey) }
        defaults.set(soundOn, forKey: "soundOn")
        defaults.set(hapticsOn, forKey: "hapticsOn")
        defaults.set(remindersOn, forKey: "remindersOn")
        defaults.set(mapTheme.rawValue, forKey: "mapTheme")
        defaults.set(tower.rawValue, forKey: "tower")
        defaults.set(onboarded, forKey: "onboarded")
        defaults.set(lastPaywallDay, forKey: "lastPaywallDay")
        defaults.set(points, forKey: "points")
        Reminders.reschedule(foes: field.foes, enabled: remindersOn, now: now)
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 初回だけ見本の敵を置く（空の画面にしない）
    func seedSamplesIfFirstLaunch() {
        guard persists, !defaults.bool(forKey: "seeded") else { return }
        defaults.set(true, forKey: "seeded")
        if field.foes.isEmpty {
            field.foes = Samples.foes(now: now, calendar: calendar)
            save()
        }
    }

    /// 撮影・デモ用：見本の戦果（過去 5 週ぶんの倒した敵）を足す
    func seedHistory() {
        field.foes.append(contentsOf: Samples.history(now: now, calendar: calendar))
    }
}

/// 見本の敵（最初の 10 秒で価値が分かるように）
enum Samples {
    static func foes(now: Date, calendar: Calendar) -> [Foe] {
        let ja = Content.isJapanese
        func foe(_ jaTitle: String, _ enTitle: String, hours: Double, weight: Int, lane: Int) -> Foe {
            Foe(title: ja ? jaTitle : enTitle, createdAt: now.addingTimeInterval(-3600), deadline: now.addingTimeInterval(hours * 3600), weight: weight, isSample: true, lane: lane)
        }
        return [
            foe("先輩にメールを返す", "Reply to my manager", hours: 0.7, weight: 1, lane: 1),
            foe("電気代を払う", "Pay the electric bill", hours: 5, weight: 1, lane: 0),
            foe("レポートを書く", "Write the report", hours: 30, weight: 3, lane: 2),
            foe("発表のスライド", "Slides for the talk", hours: 70, weight: 2, lane: 1),
            foe("部屋の片づけ", "Tidy my room", hours: 140, weight: 2, lane: 0),
        ]
    }

    /// 過去の戦果（撮影とデモのため。保存しない）
    static func history(now: Date, calendar: Calendar) -> [Foe] {
        var result: [Foe] = []
        let pattern = [2, 3, 1, 0, 4, 2, 5, 1, 3, 2, 0, 6, 2, 3, 1, 4, 2, 0, 3, 5, 2, 1, 4, 3, 2, 1, 3, 2, 4, 1, 2, 3, 0, 2]
        for (back, count) in pattern.enumerated() where count > 0 {
            guard let day = calendar.date(byAdding: .day, value: -(back + 1), to: now) else { continue }
            for i in 0..<count {
                let done = calendar.date(bySettingHour: 9 + (i * 3) % 12, minute: 10, second: 0, of: day) ?? day
                result.append(Foe(title: "—", createdAt: done.addingTimeInterval(-86_400), deadline: done.addingTimeInterval(3600 * Double(i % 3 == 0 ? -1 : 5)), weight: 1 + i % 3, doneAt: done, isSample: false, lane: i % 3))
            }
        }
        return result
    }
}
