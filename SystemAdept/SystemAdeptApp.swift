//
//  SystemAdeptApp.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.

import SwiftUI
import FirebaseCore
import BackgroundTasks

@main
struct SystemAdeptApp: App {
    // MARK: - State Objects
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var activeSystemsVM = ActiveSystemsViewModel()
    @StateObject private var themeManager = ThemeManager()
    @Environment(\ .scenePhase) private var scenePhase

    init() {
        // Configure Firebase
        FirebaseApp.configure()
        // Schedule any background tasks
        BackgroundTaskManager.shared.scheduleAppRefresh()
        // Apply initial bar styles
        themeManager.applyNavigationBarAppearance()
        themeManager.applyTabBarAppearance()

        // Clear UITableView backgrounds for SwiftUI Lists
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1️⃣ Global background
                themeManager.theme.backgroundImage
                  .ignoresSafeArea()

                // 2️⃣ Real AuthView in place of the placeholder
                AuthView()
                  .environmentObject(authVM)
                  .environmentObject(themeManager)
                  .background(Color.clear)                       // clear any default fill
                  .padding(.horizontal, themeManager.theme.spacingMedium)
            }
            .ignoresSafeArea()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Run maintenance for each active system
                for system in activeSystemsVM.activeSystems {
                    QuestQueueViewModel.runMaintenance(for: system)
                }
            }
        }
    }
}


