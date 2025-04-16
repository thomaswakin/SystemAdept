//
//  MainTabView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct MainTabView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @State private var selectedTab: Tab = .browse

  enum Tab {
    case browse, systems, quests, profile
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack {
        QuestSystemListView()
      }
      .tabItem { Label("Browse", systemImage: "list.bullet") }
      .tag(Tab.browse)

      NavigationStack {
        ActiveSystemsView()
      }
      .tabItem { Label("My Systems", systemImage: "checkmark.circle") }
      .tag(Tab.systems)

      NavigationStack {
        MyQuestsView()
      }
      .tabItem { Label("My Quests", systemImage: "flag.circle") }
      .tag(Tab.quests)

      NavigationStack {
        ProfileView()
      }
      .tabItem { Label("Profile", systemImage: "person.crop.circle") }
      .tag(Tab.profile)
    }
  }
}
