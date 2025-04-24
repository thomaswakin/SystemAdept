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
            themeManager.theme.backgroundImage
              .ignoresSafeArea()

            AuthView()
            .environmentObject(authVM)
            .environmentObject(themeManager)
          }
          .scrollContentBackground(.hidden)
          .toolbarBackground(.hidden)
          .background(Color.clear)            // make the nav container transparent
          .ignoresSafeArea()
        }
    }
}


