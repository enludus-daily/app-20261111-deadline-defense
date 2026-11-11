import Foundation

/// 倒したときの結果（点・連鎖・早めの得点）
struct Reward: Equatable, Sendable {
    var points: Int
    /// 続けて倒した数（1 なら連鎖なし）
    var combo: Int
    /// 城から遠いうちに倒した（1 日より前）
    var early: Bool
    /// 今日の波（今日までの締め切り）を全部倒した
    var clearedWave: Bool
}

/// 砲台の種類。basic は無料、ほかは Pro
enum TowerKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case basic, morning, rapid

    var id: String { rawValue }
    var isPro: Bool { self != .basic }

    /// 連鎖が続く間（秒）。連射台は長い
    var comboWindow: TimeInterval { self == .rapid ? 30 * 60 : 10 * 60 }
}

/// 戦場の決まり。画面から切り離して、テストできる形にする。
struct Battlefield: Equatable, Sendable {
    /// 道の入口にいる残り時間（これより先の締め切りは入口で待つ）
    static let horizonHours: Double = 168
    static let gateHours: Double = 1
    static let nearHours: Double = 24
    /// 城の守り（1 日の最大）
    static let castleMax = 10

    var foes: [Foe]
    var lastDefeatAt: Date?
    var combo: Int = 0

    init(foes: [Foe] = [], lastDefeatAt: Date? = nil, combo: Int = 0) {
        self.foes = foes
        self.lastDefeatAt = lastDefeatAt
        self.combo = combo
    }

    // MARK: - 位置

    /// 道の上の位置（0 = 入口、1 = 城）。残り時間を対数で縮めるので、今日の敵ほど城の近くで大きく動く。
    /// 1 週間 → 0、3 日 → 約 0.16、1 日 → 約 0.37、6 時間 → 約 0.62、1 時間 → 約 0.86、締め切り → 1
    static func progress(deadline: Date, now: Date) -> Double {
        let hours = deadline.timeIntervalSince(now) / 3600
        if hours <= 0 { return 1 }
        if hours >= horizonHours { return 0 }
        return 1 - log(1 + hours) / log(1 + horizonHours)
    }

    static func stage(deadline: Date, now: Date) -> Stage {
        let hours = deadline.timeIntervalSince(now) / 3600
        if hours <= 0 { return .breached }
        if hours <= gateHours { return .gate }
        if hours <= nearHours { return .near }
        return .far
    }

    // MARK: - 並び

    /// まだ倒していない敵。締め切りの早い順
    var active: [Foe] {
        foes.filter(\.isActive).sorted { ($0.deadline, $0.createdAt) < ($1.deadline, $1.createdAt) }
    }

    /// 次に倒す 1 体（いちばん城に近い敵）
    var nextTarget: Foe? { active.first }

    /// 今日の波：今日の終わりまでに締め切りが来る、まだ倒していない敵（過ぎたものを含む）
    func todaysWave(now: Date, calendar: Calendar) -> [Foe] {
        let end = Self.endOfDay(now, calendar: calendar)
        return active.filter { $0.deadline < end }
    }

    /// 今日、倒した敵
    func defeated(on day: Date, calendar: Calendar) -> [Foe] {
        foes.filter { foe in
            guard let done = foe.doneAt else { return false }
            return calendar.isDate(done, inSameDayAs: day)
        }
    }

    /// 城の守り（今日、城に届いた敵の重さだけ減る。翌日は元に戻る）
    func castleHealth(on day: Date, calendar: Calendar) -> Int {
        let hits = foes.reduce(0) { sum, foe in
            guard let breached = foe.breachedAt, calendar.isDate(breached, inSameDayAs: day) else { return sum }
            return sum + foe.weight
        }
        return max(0, Self.castleMax - hits)
    }

    // MARK: - 操作

    /// 敵を加える。重なりを減らすため、列を順に回す
    @discardableResult
    mutating func add(title: String, deadline: Date, weight: Int, now: Date) -> Foe? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lane = foes.filter(\.isActive).count % 3
        let foe = Foe(title: String(trimmed.prefix(80)), createdAt: now, deadline: deadline, weight: weight, lane: lane)
        foes.append(foe)
        return foe
    }

    /// 済ませた＝砲台が撃って倒す
    @discardableResult
    mutating func defeat(_ id: UUID, now: Date, calendar: Calendar, tower: TowerKind = .basic) -> Reward? {
        guard let index = foes.firstIndex(where: { $0.id == id }), foes[index].isActive else { return nil }
        let foe = foes[index]
        let wasInWave = foe.deadline < Self.endOfDay(now, calendar: calendar)
        foes[index].doneAt = now

        if let last = lastDefeatAt, now.timeIntervalSince(last) <= tower.comboWindow, now >= last {
            combo += 1
        } else {
            combo = 1
        }
        lastDefeatAt = now

        let early = Self.progress(deadline: foe.deadline, now: now) < Self.progress(deadline: now.addingTimeInterval(Self.nearHours * 3600), now: now)
        var points = foe.weight * 10
        if early { points += 5 }
        if combo > 1 { points += min(combo - 1, 5) * 2 }
        if tower == .morning, calendar.component(.hour, from: now) < 12 { points *= 2 }

        let cleared = wasInWave && todaysWave(now: now, calendar: calendar).isEmpty
        return Reward(points: points, combo: combo, early: early, clearedWave: cleared)
    }

    /// 倒したのを取り消す（押し間違い）
    mutating func revive(_ id: UUID) {
        guard let index = foes.firstIndex(where: { $0.id == id }) else { return }
        foes[index].doneAt = nil
    }

    /// 大きい敵を、小さい敵に分ける。元の敵は消え、同じ締め切りの軽い敵が生まれる
    @discardableResult
    mutating func split(_ id: UUID, into titles: [String], now: Date) -> [Foe] {
        let parts = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(4)
        guard parts.count >= 2,
              let index = foes.firstIndex(where: { $0.id == id }),
              foes[index].isActive else { return [] }
        let parent = foes.remove(at: index)
        let children = parts.enumerated().map { offset, title in
            Foe(
                title: String(title.prefix(80)),
                createdAt: now,
                deadline: parent.deadline,
                weight: 1,
                splitFrom: parent.title,
                isSample: parent.isSample,
                lane: offset % 3
            )
        }
        foes.append(contentsOf: children)
        return children
    }

    /// 明日の波に回す（責めない）。締め切りを明日の夜に動かし、道の入口のほうへ戻る
    mutating func deferToTomorrow(_ id: UUID, now: Date, calendar: Calendar) {
        guard let index = foes.firstIndex(where: { $0.id == id }), foes[index].isActive else { return }
        let start = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let base = max(foes[index].deadline, now)
        let target = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        foes[index].deadline = max(target, base.addingTimeInterval(3600))
        foes[index].deferrals += 1
    }

    mutating func remove(_ id: UUID) {
        foes.removeAll { $0.id == id }
    }

    mutating func removeSamples() {
        foes.removeAll(where: \.isSample)
    }

    /// 締め切りを過ぎた敵を城に届かせる（1 回だけ）。届いた敵を返す
    @discardableResult
    mutating func registerBreaches(now: Date) -> [Foe] {
        var hit: [Foe] = []
        for index in foes.indices where foes[index].isActive && foes[index].breachedAt == nil && foes[index].deadline <= now {
            foes[index].breachedAt = now
            hit.append(foes[index])
        }
        return hit
    }

    /// 今日の 0 時から数えて翌日の 0 時
    static func endOfDay(_ now: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
    }
}

/// 残り時間の言い方（画面と通知で使う）
enum Remaining: Equatable, Sendable {
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case overdue

    init(deadline: Date, now: Date) {
        let seconds = deadline.timeIntervalSince(now)
        if seconds <= 0 {
            self = .overdue
        } else if seconds < 3600 {
            self = .minutes(max(1, Int((seconds / 60).rounded(.up))))
        } else if seconds < 48 * 3600 {
            self = .hours(Int(seconds / 3600))
        } else {
            self = .days(Int(seconds / 86_400))
        }
    }
}
