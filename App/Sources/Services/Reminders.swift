import Foundation
import UserNotifications

/// 締め切りの少し前のお知らせ（オプトイン・端末の中だけ）
@MainActor
enum Reminders {
    nonisolated static let prefix = "foe."

    /// 許可を求める。許可されたら true
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// お知らせを出す時刻：1 日以上前に作った用事は 1 時間前、それより短いものは残りの 2 割前（最低 10 分前）
    nonisolated static func fireDate(for foe: Foe) -> Date {
        let window = foe.deadline.timeIntervalSince(foe.createdAt)
        let lead = window >= 6 * 3600 ? 3600 : max(600, window * 0.2)
        return foe.deadline.addingTimeInterval(-lead)
    }

    /// 今の敵に合わせて、お知らせを入れ直す
    static func reschedule(foes: [Foe], enabled: Bool, now: Date) {
        let center = UNUserNotificationCenter.current()
        // このアプリのお知らせは締め切りの分だけなので、全部消して入れ直す
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        let upcoming = foes
            .filter { $0.isActive && !$0.isSample }
            .map { ($0, fireDate(for: $0)) }
            .filter { $0.1 > now.addingTimeInterval(30) }
            .sorted { $0.1 < $1.1 }
            .prefix(50)
        for (foe, date) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "しめきりが近づいています")
            content.body = String(localized: "「\(foe.title)」が城の前まで来ています")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSince(now)), repeats: false)
            let request = UNNotificationRequest(identifier: prefix + foe.id.uuidString, content: content, trigger: trigger)
            center.add(request) { _ in }
        }
    }
}
