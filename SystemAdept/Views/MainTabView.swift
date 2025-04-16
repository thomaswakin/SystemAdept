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
        case player, systems, quests, browse
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Player", systemImage: "person.crop.circle") }
            .tag(Tab.player)

            NavigationStack {
                ActiveSystemsView()
            }
            .tabItem { Label("Active Systems", systemImage: "checkmark.circle") }
            .tag(Tab.systems)

            NavigationStack {
                MyQuestsView()
                    .navigationTitle("Active Quests")
            }
            .tabItem { Label("Active Quests", systemImage: "flag.circle") }
            .tag(Tab.quests)

            NavigationStack {
                QuestSystemListView()
            }
            .tabItem { Label("Browse", systemImage: "list.bullet") }
            .tag(Tab.browse)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthViewModel())
    }
}
