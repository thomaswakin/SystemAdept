//
//  MainTabView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import SwiftUI

enum Tab { case browse, systems, profile }

struct MainTabView: View {
  @State private var selected: Tab = .browse
  @State private var systemsViewID = UUID()

  var body: some View {
    TabView(selection: $selected) {
      QuestSystemListView()
        .tabItem { Label("Browse", systemImage: "list.bullet") }
        .tag(Tab.browse)

      ActiveSystemsView()
        .id(systemsViewID)                     // ← force recreation
        .tabItem { Label("My Systems", systemImage: "checkmark.circle") }
        .tag(Tab.systems)
        .onChange(of: selected) { new in
          if new == .systems {
            systemsViewID = UUID()             // reset when re‑selected
          }
        }

      ProfileView()
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        .tag(Tab.profile)
    }
  }
}
