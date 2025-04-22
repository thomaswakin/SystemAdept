//
//  SystemAdeptApp.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct SystemAdeptApp: App {
  // Initialize Firebase in your App’s init
  init() {
    FirebaseApp.configure()
      
    // Prepare background tasks
    BackgroundTaskManager.shared.scheduleAppRefresh()
  }

  @StateObject private var authVM = AuthViewModel()
  @StateObject private var activeSystemsVM = ActiveSystemsViewModel()
  @Environment(\.scenePhase) private var scenePhase
    
  var body: some Scene {
    WindowGroup {
      Group {
        if authVM.isLoggedIn {
          MainTabView()
            .environmentObject(authVM)
            .environmentObject(activeSystemsVM)
        } else {
          AuthView()
            .environmentObject(authVM)
        }
      }
    }
    .onChange(of: scenePhase) { newPhase in
        if newPhase == .active {
            // For every system the user has, run maintenance
            for sys in activeSystemsVM.activeSystems {
                QuestQueueViewModel.runMaintenance(for: sys)
            }
        }
    }
  }
}

