//
//  NotificationManager.swift
//  SystemAdept
//
//  Created by Thomas Akin on 5/1/25.
//

import Foundation
import UserNotifications

/// Manages scheduling of morning reminders and expiration alerts.
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    /// Schedule the next morning reminder at the end of rest.
    func scheduleNextMorningReminder(
       restEndHour: Int,
       restEndMinute: Int,
       activeQuests: [ActiveQuest],
       authVM: AuthViewModel,
       appState: AppState
    ) {
        // 1) Clear existing reminder
        center.removePendingNotificationRequests(withIdentifiers: ["morningReminder"])

        // 2) Compute the next rest-end Date
        let now = Date()
        let cal = Calendar.current
        let comps = DateComponents(hour: restEndHour, minute: restEndMinute)
        guard let nextRestEnd = cal.nextDate(
            after: now,
            matching: comps,
            matchingPolicy: .nextTime,
            direction: .forward
        ) else { return }

        // 3) Compute rest duration (may cross midnight)
        let startHour   = authVM.userProfile?.restStartHour   ?? 22
        let startMin    = authVM.userProfile?.restStartMinute ?? 0
        let startTotal  = startHour * 60 + startMin
        let endTotal    = restEndHour * 60 + restEndMinute
        let restMins: Int
        if endTotal >= startTotal {
            restMins = endTotal - startTotal
        } else {
            restMins = (24 * 60 - startTotal) + endTotal
        }
        let restDuration = TimeInterval(restMins * 60)

        // 4) Build the same window your Daily filter uses: 24h + restDuration
        let windowEnd = nextRestEnd
            .addingTimeInterval(24 * 3600)
            .addingTimeInterval(restDuration)

        // 5) Count quests due in that window
        let dailyCount = activeQuests.filter {
            $0.progress.status == .available &&
            ($0.progress.expirationTime ?? .distantFuture) <= windowEnd
        }.count
        let outstandingCount = activeQuests.filter { $0.progress.status == .available }.count
        let expiredCount     = activeQuests.filter { $0.progress.status == .failed    }.count

        let (body, navTab): (String, AppState.Tab) = {
            if dailyCount > 0 {
                return ("System Adept: \(dailyCount) quests due today.", .quests)
            } else if outstandingCount > 0 {
                return ("System Adept: \(outstandingCount) outstanding quests", .quests)
            } else if expiredCount > 0 {
                return ("System Adept: \(expiredCount) expired quests waiting reactivation", .quests)
            } else {
                return ("System Adept: No active quests. Enable a Quest System", .systems)
            }
        }()

        // 6) Create notification content
        let content = UNMutableNotificationContent()
        content.title = "System Adept"
        content.body  = body
        let pageValue = appState.initialQuestPage?.rawValue ?? MyQuestsView.Page.daily.rawValue
        content.userInfo = [
            "navigateTab":  navTab.rawValue,
            "navigatePage": pageValue
        ]

        // 7) Schedule it
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: nextRestEnd
            ),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "morningReminder",
            content:    content,
            trigger:    trigger
        )
        center.add(request)

        // ─── Debug logging ───
        print("🔔 Scheduled morningReminder for \(nextRestEnd) (windowEnd = \(windowEnd))")
        center.getPendingNotificationRequests { reqs in
            print("    👉 Pending IDs:", reqs.map(\.identifier))
        }
    }

    /// Schedule 1-hour-prior expiration alerts for each available quest.
    func scheduleExpiryAlerts(activeQuests: [ActiveQuest]) {
        // Remove old alerts
        let ids = activeQuests.map { "\($0.id)-expiring" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let cal = Calendar.current
        for aq in activeQuests {
            guard aq.progress.status == .available,
                  let exp = aq.progress.expirationTime else { continue }

            let alertDate = exp.addingTimeInterval(-3600)
            if alertDate <= Date() { continue }

            let content = UNMutableNotificationContent()
            content.title    = "Quest Expiring Soon"
            content.body     = "Active Quest “\(aq.quest.questName)” is expiring in 1 hour!"
            content.userInfo = [
                "navigateTab":  AppState.Tab.quests.rawValue,
                "navigatePage": MyQuestsView.Page.daily.rawValue
            ]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: alertDate
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(aq.id)-expiring",
                content:    content,
                trigger:    trigger
            )
            center.add(request)
        }
    }
}
