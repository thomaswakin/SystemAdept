//
//  SystemAdeptApp.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.
//

import SwiftUI
import FirebaseCore
import BackgroundTasks

@main
struct SystemAdeptApp: App {
    // MARK: - Uninitialized @StateObjects
    @StateObject private var activeSystemsVM: ActiveSystemsViewModel
    @StateObject private var questsVM: MyQuestsViewModel
    @StateObject private var appState: AppState

    // Other state objects
    @StateObject private var authVM       = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()

    init() {
        FirebaseApp.configure()

        let asvm = ActiveSystemsViewModel()
        let qvm  = MyQuestsViewModel()
        _activeSystemsVM = StateObject(wrappedValue: asvm)
        _questsVM       = StateObject(wrappedValue: qvm)
        _appState       = StateObject(wrappedValue: AppState(
            activeSystemsVM: asvm,
            questsVM: qvm
        ))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // ← Here’s the switch:
                if authVM.userProfile == nil {
                    // Not logged in → show Auth flow
                    AuthView()
                        .environmentObject(authVM)
                        .environmentObject(themeManager)
                } else {
                    // Logged in → show main UI
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
