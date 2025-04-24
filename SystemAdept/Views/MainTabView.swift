//
//  MainTabView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedTab: Tab = .player

    enum Tab {
        case player, systems, quests
    }

    var body: some View {
      ZStack {
        TabView(selection: $selectedTab) {
          // Player
          NavigationStack {
            ProfileView()
          }
          .background(Color.clear)       // ← make nav content transparent
          .tabItem { Label("Player", systemImage: "person.crop.circle") }
          .tag(Tab.player)

          // Systems
          NavigationStack {
            SystemsTabView()
          }
          .background(Color.clear)
          .tabItem { Label("Systems", systemImage: "checkmark.circle") }
          .tag(Tab.systems)

          // Quests
          NavigationStack {
            MyQuestsView()
              .navigationTitle("Active Quests")
          }
          .background(Color.clear)
          .tabItem { Label("Active Quests", systemImage: "flag.circle") }
          .tag(Tab.quests)
        }
        .background(Color.clear)        // ← make TabView transparent
        .accentColor(themeManager.theme.accentColor)
      }
      .background(Color.clear)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthViewModel())
            .background(Color.clear)
    }
}


// MARK: - SystemsTabView

/// Combines ActiveSystemsView and QuestSystemListView under a segmented filter.
struct SystemsTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    enum Filter: String, CaseIterable, Identifiable {
        case active    = "Active Systems"
        case available = "Available Systems"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .active

    var body: some View {
        VStack {
            // Segmented picker to toggle between views
            Picker("Show", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.rawValue).tag(f)
                        .font(themeManager.theme.headingLargeFont)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Show the appropriate view
            switch filter {
            case .active:
                MySystemsListView()
            case .available:
                QuestSystemListView()
            }
        }
        .background(Color.clear)
        .navigationTitle("Systems")
    }
}
