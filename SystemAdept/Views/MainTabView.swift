//
//  MainTabView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab: Tab = .player

    enum Tab {
        case player, systems, quests
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Player/Profile Tab
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Player", systemImage: "person.crop.circle")
            }
            .tag(Tab.player)

            // Systems Tab (combines Active & Available)
            NavigationStack {
                SystemsTabView()
            }
            .tabItem {
                Label("Systems", systemImage: "checkmark.circle")
            }
            .tag(Tab.systems)

            // My Quests Tab
            NavigationStack {
                MyQuestsView()
                    .navigationTitle("Active Quests")
            }
            .tabItem {
                Label("Active Quests", systemImage: "flag.circle")
            }
            .tag(Tab.quests)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthViewModel())
    }
}


// MARK: - SystemsTabView

/// Combines ActiveSystemsView and QuestSystemListView under a segmented filter.
struct SystemsTabView: View {
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
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Show the appropriate view
            switch filter {
            case .active:
                ActiveSystemsView()
            case .available:
                QuestSystemListView()
            }
        }
        .navigationTitle("Systems")
    }
}
