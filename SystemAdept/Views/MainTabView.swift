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
        ProfileView()
      }
      .tabItem { Label("Profile", systemImage: "person.crop.circle") }
      .tag(Tab.profile)

      NavigationStack {
        ActiveSystemsView()
      }
      .tabItem { Label("Systems", systemImage: "checkmark.circle") }
      .tag(Tab.systems)
        
      NavigationStack {
        QuestSystemListView()
      }
      .tabItem { Label("Browse", systemImage: "list.bullet") }
      .tag(Tab.browse)
        
      NavigationStack {
        MyQuestsView()
      }
      .tabItem { Label("Quests", systemImage: "flag.circle") }
      .tag(Tab.quests)


    }
  }
}
