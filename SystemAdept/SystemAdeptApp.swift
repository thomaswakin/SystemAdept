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
  }

  @StateObject private var authVM = AuthViewModel()

  var body: some Scene {
    WindowGroup {
      Group {
        if authVM.isLoggedIn {
          MainTabView()
            .environmentObject(authVM)
        } else {
          AuthView()
            .environmentObject(authVM)
        }
      }
    }
  }
}

