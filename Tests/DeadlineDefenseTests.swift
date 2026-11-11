import Foundation
import Testing
@testable import DeadlineDefense

/// 2026-11-11（水）10:00 東京
private let tokyo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11) -> Date {
    tokyo.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private let now = date(11, 10)

struct MarchTests {
    @Test func farDeadlinesWaitAtTheEntrance() {
        #expect(Battlefield.progress(deadline: now.addingTimeInterval(10 * 86_400), now: now) == 0)
    }

    @Test func overdueFoesAreAtTheCastle() {
        #expect(Battlefield.progress(deadline: now.addingTimeInterval(-60), now: now) == 1)
    }

    @Test func closerDeadlinesAreCloserToTheCastle() {
        let week = Battlefield.progress(deadline: now.addingTimeInterval(3 * 86_400), now: now)
        let day = Battlefield.progress(deadline: now.addingTimeInterval(86_400), now: now)
        let hour = Battlefield.progress(deadline: now.addingTimeInterval(3600), now: now)
        #expect(week < day)
        #expect(day < hour)
        #expect(hour < 1)
        #expect(abs(day - 0.37) < 0.02)
        #expect(abs(hour - 0.865) < 0.02)
    }

    @Test(arguments: [(30.0, Stage.gate), (5 * 60.0, Stage.near), (30 * 60.0, Stage.far), (-1.0, Stage.breached)])
    func stagesFollowTheRemainingTime(minutes: Double, expected: Stage) {
        #expect(Battlefield.stage(deadline: now.addingTimeInterval(minutes * 60), now: now) == expected)
    }

    @Test func remainingTimeReadsNaturally() {
        #expect(Remaining(deadline: now.addingTimeInterval(90), now: now) == .minutes(2))
        #expect(Remaining(deadline: now.addingTimeInterval(5 * 3600 + 10), now: now) == .hours(5))
        #expect(Remaining(deadline: now.addingTimeInterval(3 * 86_400), now: now) == .days(3))
        #expect(Remaining(deadline: now.addingTimeInterval(-5), now: now) == .overdue)
    }

    @Test func pathRunsFromEntranceToCastle() {
        let path = MarchPath(size: CGSize(width: 300, height: 400))
        let start = path.point(at: 0)
        let end = path.point(at: 1)
        #expect(abs(start.x - 30) < 1 && abs(start.y - 20) < 1)
        #expect(abs(end.x - 150) < 1 && abs(end.y - 348) < 1)
        // 道の長さに沿って均等：半分の点は、両端から同じくらいの道のり
        let mid = path.point(at: 0.5)
        #expect(mid != start && mid != end)
        #expect(path.totalLength > 400)
    }
}

struct DeadlineChipTests {
    @Test func tonightIsElevenPM() {
        #expect(DeadlineChip.tonight.deadline(from: now, calendar: tokyo) == date(11, 23))
    }

    @Test func lateTonightGivesTwoHours() {
        let late = date(11, 22, 30)
        #expect(DeadlineChip.tonight.deadline(from: late, calendar: tokyo) == late.addingTimeInterval(7200))
    }

    @Test func tomorrowIsSixPM() {
        #expect(DeadlineChip.tomorrow.deadline(from: now, calendar: tokyo) == date(12, 18))
    }

    @Test func thisWeekIsNextSunday() {
        // 2026-11-11 は水曜。次の日曜は 11-15
        #expect(DeadlineChip.thisWeek.deadline(from: now, calendar: tokyo) == date(15, 18))
        // 日曜なら 1 週間後
        #expect(DeadlineChip.thisWeek.deadline(from: date(15, 9), calendar: tokyo) == date(22, 18))
    }
}

struct BattleTests {
    @Test func addingIgnoresBlankTitles() {
        var field = Battlefield()
        #expect(field.add(title: "   ", deadline: now, weight: 2, now: now) == nil)
        #expect(field.foes.isEmpty)
    }

    @Test func nextTargetIsTheClosestToTheCastle() {
        var field = Battlefield()
        field.add(title: "来週の発表", deadline: date(18, 10), weight: 3, now: now)
        field.add(title: "今夜の返信", deadline: date(11, 21), weight: 1, now: now)
        #expect(field.nextTarget?.title == "今夜の返信")
    }

    @Test func defeatingGivesPointsByWeightAndEarliness() {
        var field = Battlefield()
        let heavy = field.add(title: "レポート", deadline: date(14, 18), weight: 3, now: now)!
        let reward = field.defeat(heavy.id, now: now, calendar: tokyo)
        #expect(reward?.points == 35)
        #expect(reward?.early == true)
        #expect(field.active.isEmpty)
        // 2 回は倒せない
        #expect(field.defeat(heavy.id, now: now, calendar: tokyo) == nil)
    }

    @Test func quickSuccessionBuildsACombo() {
        var field = Battlefield()
        let a = field.add(title: "a", deadline: date(11, 20), weight: 1, now: now)!
        let b = field.add(title: "b", deadline: date(11, 20), weight: 1, now: now)!
        let c = field.add(title: "c", deadline: date(11, 20), weight: 1, now: now)!
        #expect(field.defeat(a.id, now: now, calendar: tokyo)?.combo == 1)
        #expect(field.defeat(b.id, now: now.addingTimeInterval(120), calendar: tokyo)?.combo == 2)
        // 10 分より空くと途切れる
        #expect(field.defeat(c.id, now: now.addingTimeInterval(120 + 11 * 60), calendar: tokyo)?.combo == 1)
    }

    @Test func rapidTowerKeepsTheComboLonger() {
        var field = Battlefield()
        let a = field.add(title: "a", deadline: date(11, 20), weight: 1, now: now)!
        let b = field.add(title: "b", deadline: date(11, 20), weight: 1, now: now)!
        field.defeat(a.id, now: now, calendar: tokyo, tower: .rapid)
        #expect(field.defeat(b.id, now: now.addingTimeInterval(20 * 60), calendar: tokyo, tower: .rapid)?.combo == 2)
    }

    @Test func morningTowerDoublesBeforeNoon() {
        var field = Battlefield()
        let a = field.add(title: "a", deadline: date(11, 11), weight: 1, now: now)!
        #expect(field.defeat(a.id, now: now, calendar: tokyo, tower: .morning)?.points == 20)
    }

    @Test func clearingTodaysWaveIsReported() {
        var field = Battlefield()
        let a = field.add(title: "a", deadline: date(11, 20), weight: 1, now: now)!
        let b = field.add(title: "b", deadline: date(11, 21), weight: 1, now: now)!
        field.add(title: "later", deadline: date(13, 21), weight: 1, now: now)
        #expect(field.todaysWave(now: now, calendar: tokyo).count == 2)
        #expect(field.defeat(a.id, now: now, calendar: tokyo)?.clearedWave == false)
        #expect(field.defeat(b.id, now: now, calendar: tokyo)?.clearedWave == true)
    }

    @Test func defeatingAFutureFoeDoesNotClaimAWaveClear() {
        var field = Battlefield()
        let later = field.add(title: "later", deadline: date(13, 21), weight: 1, now: now)!
        #expect(field.defeat(later.id, now: now, calendar: tokyo)?.clearedWave == false)
    }

    @Test func splittingMakesLightFoesWithTheSameDeadline() {
        var field = Battlefield()
        let big = field.add(title: "企画書", deadline: date(13, 18), weight: 3, now: now)!
        let parts = field.split(big.id, into: ["ねらいを1行", " ", "案を3つ", "書く"], now: now)
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { $0.weight == 1 && $0.deadline == big.deadline && $0.splitFrom == "企画書" })
        #expect(!field.foes.contains { $0.id == big.id })
    }

    @Test func splittingNeedsTwoParts() {
        var field = Battlefield()
        let big = field.add(title: "企画書", deadline: date(13, 18), weight: 3, now: now)!
        #expect(field.split(big.id, into: ["1つだけ"], now: now).isEmpty)
        #expect(field.foes.count == 1)
    }

    @Test func deferringMovesToTomorrowNightWithoutBlame() {
        var field = Battlefield()
        let foe = field.add(title: "返信", deadline: date(11, 9), weight: 1, now: date(11, 8))!
        field.deferToTomorrow(foe.id, now: now, calendar: tokyo)
        let moved = field.foes[0]
        #expect(moved.deadline == date(12, 21))
        #expect(moved.deferrals == 1)
        #expect(moved.isActive)
    }

    @Test func breachesAreCountedOnceAndHurtTheCastleGently() {
        var field = Battlefield()
        field.add(title: "late", deadline: date(11, 9), weight: 2, now: date(10, 9))
        field.add(title: "ok", deadline: date(12, 9), weight: 3, now: now)
        #expect(field.registerBreaches(now: now).count == 1)
        #expect(field.registerBreaches(now: now).isEmpty)
        #expect(field.castleHealth(on: now, calendar: tokyo) == Battlefield.castleMax - 2)
        #expect(field.castleHealth(on: date(12, 10), calendar: tokyo) == Battlefield.castleMax)
    }

    @Test func samplesCanBeCleared() {
        var field = Battlefield(foes: [Foe(title: "見本", createdAt: now, deadline: date(12, 9), isSample: true)])
        field.add(title: "本物", deadline: date(12, 9), weight: 1, now: now)
        field.removeSamples()
        #expect(field.foes.map(\.title) == ["本物"])
    }
}

struct ChronicleTests {
    private func done(_ day: Int, _ hour: Int, weight: Int = 1, deadlineDay: Int? = nil) -> Foe {
        Foe(title: "x", createdAt: date(day, 8), deadline: date(deadlineDay ?? day, 23), weight: weight, doneAt: date(day, hour))
    }

    @Test func streakCountsConsecutiveDaysWithADefeat() {
        let chronicle = Chronicle(foes: [done(9, 10), done(10, 12), done(11, 9)], calendar: tokyo)
        #expect(chronicle.streak(now: now) == 3)
    }

    @Test func streakSurvivesUntilTheDayIsOver() {
        let chronicle = Chronicle(foes: [done(9, 10), done(10, 12)], calendar: tokyo)
        #expect(chronicle.streak(now: now) == 2)
    }

    @Test func streakBreaksAfterAMissedDay() {
        let chronicle = Chronicle(foes: [done(8, 10), done(10, 12)], calendar: tokyo)
        #expect(chronicle.streak(now: now) == 1)
    }

    @Test func castleLevelGrowsWithDefeatedWeight() {
        let foes = (0..<6).map { _ in done(10, 10, weight: 3) }
        let chronicle = Chronicle(foes: foes, calendar: tokyo)
        #expect(chronicle.totalWeight == 18)
        #expect(chronicle.castleLevel == 3)
        #expect(Chronicle(foes: [], calendar: tokyo).castleLevel == 1)
    }

    @Test func weeksEndWithThisWeek() {
        let chronicle = Chronicle(foes: [done(11, 9), done(11, 10), done(4, 10)], calendar: tokyo)
        let weeks = chronicle.weeks(4, now: now)
        #expect(weeks.count == 4)
        #expect(weeks.allSatisfy { $0.count == 7 })
        // 水曜（weekday 4）は週の 4 番目
        #expect(weeks[3][3].defeated == 2)
        #expect(weeks[2][3].defeated == 1)
    }

    @Test func onTimeRateAndBestHour() {
        let late = done(11, 9, deadlineDay: 10)
        let chronicle = Chronicle(foes: [done(10, 21), done(9, 21), late], calendar: tokyo)
        #expect(chronicle.onTimeRate.map { abs($0 - 2.0 / 3.0) < 0.001 } == true)
        #expect(chronicle.bestHour == 21)
    }
}

struct ContentTests {
    @Test func thereIsMoreThanAMonthOfTactics() {
        #expect(Content.tactics.count >= 40)
        #expect(Content.tactics.allSatisfy { !$0.title.en.isEmpty && !$0.detail.en.isEmpty && !$0.title.ja.isEmpty })
    }

    @Test func templatesHaveFreeAndProSets() {
        #expect(Content.templates.count >= 30)
        #expect(Content.templates.filter(\.isFree).count == 8)
        #expect(Content.templates.allSatisfy { $0.steps.count >= 2 && $0.steps.allSatisfy { !$0.en.isEmpty } })
        #expect(Set(Content.templates.map(\.id)).count == Content.templates.count)
    }

    @Test func templatesAreSuggestedFromTheTitle() {
        #expect(Content.suggestedTemplate(for: "経済学のレポート", includePro: false)?.id == "report")
        #expect(Content.suggestedTemplate(for: "Reply to Sam's email", includePro: false)?.id == "mail")
        #expect(Content.suggestedTemplate(for: "確定申告", includePro: false) == nil)
        #expect(Content.suggestedTemplate(for: "確定申告", includePro: true)?.id == "taxes")
    }

    @Test func theSameDayGivesTheSameTactic() {
        #expect(Content.tactic(for: now, calendar: tokyo) == Content.tactic(for: date(11, 23), calendar: tokyo))
        #expect(Content.tactic(for: now, calendar: tokyo) != Content.tactic(for: date(12, 10), calendar: tokyo))
    }
}
