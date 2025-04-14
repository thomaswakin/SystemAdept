//
//  MainTabView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import SwiftUI

struct MainTabView: View {
  @EnvironmentObject var authVM: AuthViewModel

  var body: some View {
    TabView {
      QuestSystemListView()
        .tabItem {
          Label("Browse", systemImage: "list.bullet")
        }

      ActiveSystemsView()
        .tabItem {
          Label("My Systems", systemImage: "checkmark.circle")
        }

      ProfileView()
        .tabItem {
          Label("Profile", systemImage: "person.crop.circle")
        }
    }
  }
}