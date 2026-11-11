import Foundation

/// 1 日の戦いの記録（倒した敵から計算する。別に保存しない）
struct DayRecord: Equatable, Sendable {
    var day: Date
    var defeated: Int
    var points: Int
    var breaches: Int
    var onTime: Int

    /// マスの濃さ（0〜4）。倒した数の区切りで決める（最大値に合わせない）
    var level: Int {
        switch defeated {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        case 4...5: return 3
        default: return 4
        }
    }
}

/// 積み上げ：守った日数・マス・城のレベル
struct Chronicle: Equatable, Sendable {
    let foes: [Foe]
    let calendar: Calendar

    static func == (lhs: Chronicle, rhs: Chronicle) -> Bool { lhs.foes == rhs.foes }

    func record(for day: Date) -> DayRecord {
        var defeated = 0, points = 0, breaches = 0, onTime = 0
        for foe in foes {
            if let done = foe.doneAt, calendar.isDate(done, inSameDayAs: day) {
                defeated += 1
                points += foe.weight * 10
                if done <= foe.deadline { onTime += 1 }
            }
            if let breached = foe.breachedAt, calendar.isDate(breached, inSameDayAs: day) {
                breaches += 1
            }
        }
        return DayRecord(day: calendar.startOfDay(for: day), defeated: defeated, points: points, breaches: breaches, onTime: onTime)
    }

    /// 守った日：1 体以上倒した日が続いた数。今日まだ倒していなくても、昨日まで続いていれば数える（責めない）
    func streak(now: Date) -> Int {
        var day = calendar.startOfDay(for: now)
        if record(for: day).defeated == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while record(for: day).defeated > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
            if count > 3660 { break }
        }
        return count
    }

    /// これまでに倒した敵の数
    var totalDefeated: Int { foes.filter(\.isDone).count }

    /// これまでに倒した重さ（城のレベルのもと）
    var totalWeight: Int { foes.filter(\.isDone).reduce(0) { $0 + $1.weight } }

    /// 城のレベル（1〜10）。重さ 8 ごとに 1 つ上がる。砲台と旗が増える
    var castleLevel: Int { min(10, 1 + totalWeight / 8) }

    /// 次のレベルまでの割合（0〜1）
    var levelProgress: Double {
        if castleLevel >= 10 { return 1 }
        return Double(totalWeight % 8) / 8
    }

    /// 週ごとのマス（古い週から。各週は日曜はじまりの 7 日）
    func weeks(_ count: Int, now: Date) -> [[DayRecord]] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) else { return [] }
        return (0..<count).reversed().map { back in
            let start = calendar.date(byAdding: .day, value: -7 * back, to: thisWeekStart) ?? thisWeekStart
            return (0..<7).map { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                if day > today { return DayRecord(day: day, defeated: 0, points: 0, breaches: 0, onTime: 0) }
                return record(for: day)
            }
        }
    }

    /// 締め切りまでに倒した割合（0〜1。倒した敵がなければ nil）
    var onTimeRate: Double? {
        let done = foes.filter(\.isDone)
        guard !done.isEmpty else { return nil }
        let onTime = done.filter { ($0.doneAt ?? .distantFuture) <= $0.deadline }.count
        return Double(onTime) / Double(done.count)
    }

    /// よく倒す時間帯（0〜23 時。倒した敵がなければ nil）
    var bestHour: Int? {
        var counts = [Int: Int]()
        for foe in foes {
            guard let done = foe.doneAt else { continue }
            counts[calendar.component(.hour, from: done), default: 0] += 1
        }
        return counts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key
    }

    /// 分けて倒した敵の数（先延ばし対策がどれだけ効いたか）
    var splitDefeated: Int { foes.filter { $0.isDone && $0.splitFrom != nil }.count }
}
