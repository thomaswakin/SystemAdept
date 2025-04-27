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
    // MARK: - Uninitialized @StateObjects (we wire them up in init)
    @StateObject private var activeSystemsVM: ActiveSystemsViewModel
    @StateObject private var questsVM: MyQuestsViewModel
    @StateObject private var appState: AppState

    // Other state objects
    @StateObject private var authVM       = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()

    init() {
        // 1) Configure Firebase
        FirebaseApp.configure()

        // 2) Instantiate the two VMs that AppState requires
        let asvm = ActiveSystemsViewModel()
        let qvm  = MyQuestsViewModel()

        // 3) Wire them into SwiftUI
        _activeSystemsVM = StateObject(wrappedValue: asvm)
        _questsVM       = StateObject(wrappedValue: qvm)

        // 4) Initialize AppState with those dependencies
        _appState = StateObject(wrappedValue: AppState(
            activeSystemsVM: asvm,
            questsVM: qvm
        ))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Full-screen background image
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // **Correct root: MainTabView**
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
