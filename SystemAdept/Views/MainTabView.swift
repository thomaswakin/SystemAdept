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

    enum Tab: Hashable {
        case player, systems, quests
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen background
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    // Player/Profile Tab
                    NavigationStack {
                        VStack(spacing: themeManager.theme.spacingMedium) {
                            // Header bar
                            Text("Player")
                                .font(themeManager.theme.headingLargeFont)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, themeManager.theme.spacingSmall)
                                .background(themeManager.theme.secondaryTextColor.opacity(0.8))
                                .padding(.horizontal, -themeManager.theme.spacingMedium)

                            ProfileView()
                        }
                        .padding(.horizontal, themeManager.theme.spacingMedium)
                        .frame(maxWidth: 400)
                        .background(Color.clear)
                        .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                    }
                    .tabItem { Label("Player", systemImage: "person.crop.circle") }
                    .tag(Tab.player)

                    // Systems Tab
                    NavigationStack {
                        VStack(spacing: themeManager.theme.spacingMedium) {
                            // Header bar
                            Text("Systems")
                                .font(themeManager.theme.headingLargeFont)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, themeManager.theme.spacingSmall)
                                .background(themeManager.theme.secondaryTextColor.opacity(0.8))
                                .padding(.horizontal, -themeManager.theme.spacingMedium)

                            SystemsTabView()
                        }
                        .padding(.horizontal, themeManager.theme.spacingMedium)
                        .frame(maxWidth: 400)
                        .background(Color.clear)
                        .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                    }
                    .tabItem { Label("Systems", systemImage: "checkmark.circle") }
                    .tag(Tab.systems)

                    // Active Quests Tab
                    NavigationStack {
                        VStack(spacing: themeManager.theme.spacingMedium) {
                            // Header bar
                            Text("Active Quests")
                                .font(themeManager.theme.headingLargeFont)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, themeManager.theme.spacingSmall)
                                .background(themeManager.theme.secondaryTextColor.opacity(0.8))
                                .padding(.horizontal, -themeManager.theme.spacingMedium)

                            MyQuestsView()
                        }
                        .padding(.horizontal, themeManager.theme.spacingMedium)
                        .frame(maxWidth: 400)
                        .background(Color.clear)
                        .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                    }
                    .tabItem { Label("Active Quests", systemImage: "flag.circle") }
                    .tag(Tab.quests)
                }
                .accentColor(themeManager.theme.accentColor)
                .font(themeManager.theme.bodyMediumFont)
                .background(Color.clear)
            }
            .background(Color.clear)
        }
        .accentColor(themeManager.theme.accentColor)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
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
        VStack(spacing: themeManager.theme.spacingMedium) {
            // Segmented Picker
            Picker("Show Systems", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.rawValue)
                        .font(themeManager.theme.headingMediumFont)
                        .foregroundColor(themeManager.theme.primaryTextColor)
                }
            }
            .pickerStyle(.segmented)
            .tint(themeManager.theme.accentPrimary)
            .padding(.horizontal, themeManager.theme.paddingMedium)
            .padding(.top, themeManager.theme.spacingMedium)

            Group {
                switch filter {
                case .active:
                    MySystemsListView()
                case .available:
                    QuestSystemListView()
                }
            }
            .background(Color.clear)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthViewModel())
            .environmentObject(ThemeManager())
            .background(Color.clear)
    }
}


