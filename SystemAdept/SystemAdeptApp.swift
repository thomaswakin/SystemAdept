//
// SystemAdeptApp.swift
// SystemAdept
//
// Created by Thomas Akin on 3/29/25.
//

import SwiftUI
import FirebaseCore
import BackgroundTasks
import UserNotifications

@main
struct SystemAdeptApp: App {
    // MARK: - StateObjects
    @StateObject private var activeSystemsVM: ActiveSystemsViewModel
    @StateObject private var questsVM: MyQuestsViewModel
    @StateObject private var appState: AppState

    @StateObject private var authVM: AuthViewModel
    @StateObject private var themeManager = ThemeManager()

    init() {
        FirebaseApp.configure()

        // 1) Instantiate all view‐models (including auth)
        let auth = AuthViewModel()
        let asvm = ActiveSystemsViewModel()
        let qvm  = MyQuestsViewModel()

        // 2) Initialize the @StateObject wrappers
        _authVM           = StateObject(wrappedValue: auth)
        _activeSystemsVM  = StateObject(wrappedValue: asvm)
        _questsVM         = StateObject(wrappedValue: qvm)

        // 3) Build AppState now that authVM, systemsVM, and questsVM exist
        let state = AppState(
            activeSystemsVM: asvm,
            questsVM:        qvm,
            authVM:          auth
        )
        _appState = StateObject(wrappedValue: state)

        // 4) Request notification permission and wire the delegate
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error = error {
                print("🔔 Notification auth error:", error)
            }
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationDelegate.shared.appState = state
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                if authVM.userProfile == nil {
                    AuthView()
                        .environmentObject(authVM)
                        .environmentObject(themeManager)
                } else {
                    MainTabView()
                        .environmentObject(authVM)
                        .environmentObject(activeSystemsVM)
                        .environmentObject(questsVM)
                        .environmentObject(themeManager)
                        .environmentObject(appState)
                }
            }
        }
    }
}
