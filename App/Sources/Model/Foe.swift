import Foundation

/// 締め切りのある用事。地図の上では、城へ向かって歩く「しめきり」の敵になる。
struct Foe: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var deadline: Date
    /// 重さ（1 軽い・2 ふつう・3 重い）。敵の大きさと、倒したときの点になる
    var weight: Int
    var doneAt: Date?
    /// 締め切りを過ぎて城に届いた時刻（1 回だけ記録する）
    var breachedAt: Date?
    /// 「明日の波に回す」をした回数
    var deferrals: Int
    /// 分けて生まれた敵なら、元の用事の名前
    var splitFrom: String?
    /// 最初に入っている見本の敵
    var isSample: Bool
    /// 道の上で少しずらす列（0〜2）。重なりを減らす
    var lane: Int

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        deadline: Date,
        weight: Int = 2,
        doneAt: Date? = nil,
        breachedAt: Date? = nil,
        deferrals: Int = 0,
        splitFrom: String? = nil,
        isSample: Bool = false,
        lane: Int = 1
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.deadline = deadline
        self.weight = Foe.clampWeight(weight)
        self.doneAt = doneAt
        self.breachedAt = breachedAt
        self.deferrals = deferrals
        self.splitFrom = splitFrom
        self.isSample = isSample
        self.lane = min(max(lane, 0), 2)
    }

    static func clampWeight(_ weight: Int) -> Int { min(max(weight, 1), 3) }

    var isDone: Bool { doneAt != nil }
    var isActive: Bool { doneAt == nil }
}

/// 道の上のどこにいるか。城までの距離＝締め切りまでの残り時間。
enum Stage: Int, Equatable, Comparable, Sendable {
    /// まだ遠い（1 日より先）
    case far
    /// 近づいている（1 日以内）
    case near
    /// 城の前（1 時間以内）
    case gate
    /// 締め切りを過ぎて城に届いた
    case breached

    static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// 締め切りの早いえらび方（追加を 3 秒で済ませるためのチップ）
enum DeadlineChip: String, CaseIterable, Identifiable, Sendable {
    case tonight, tomorrow, thisWeek

    var id: String { rawValue }

    /// 今夜＝今日の 23 時（22 時を過ぎていたら 2 時間後）。明日＝明日の 18 時。今週＝次の日曜の 18 時（日曜なら 1 週間後）
    func deadline(from now: Date, calendar: Calendar) -> Date {
        switch self {
        case .tonight:
            let hour = calendar.component(.hour, from: now)
            if hour >= 22 { return now.addingTimeInterval(2 * 3600) }
            return calendar.date(bySettingHour: 23, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(3600)
        case .tomorrow:
            let start = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        case .thisWeek:
            let start = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: now) // 1 = 日曜
            var days = (8 - weekday) % 7
            if days == 0 { days = 7 }
            let sunday = calendar.date(byAdding: .day, value: days, to: start) ?? now
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: sunday) ?? sunday
        }
    }
}
