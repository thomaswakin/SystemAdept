// NotificationDelegate.swift
// SystemAdept
//
// Created by Thomas Akin on 5/1/25.
//

import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    weak var appState: AppState?

    // Called when the user taps a delivered notification
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo

        if let tabHash = info["navigateTab"] as? Int,
           let tab     = AppState.Tab(rawValue: tabHash) {
            appState?.selectedTab = tab
        }
        if let pageRaw = info["navigatePage"] as? Int,
           let page    = MyQuestsView.Page(rawValue: pageRaw) {
            appState?.initialQuestPage = page
        }

        completionHandler()
    }

    // Show banners/sounds even when app is in foreground
    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
