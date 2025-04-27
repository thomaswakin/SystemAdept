//
//  MyQuestsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct MyQuestsView: View {
    @StateObject private var vm = MyQuestsViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    // Pager state
    @State private var selectedPage: Page
    @State private var ascending = true
    @State private var now = Date()
    @State private var showDebuffMessage = false
    
    
    init(initialPage: Page = .daily) {
        _selectedPage = State(initialValue: initialPage)
    }

    // Define your four pages
    enum Page: Int, CaseIterable {
        case daily, expired, active, complete
        var title: String {
            switch self {
            case .daily:    return "Daily Quests"
            case .expired:  return "Expired Quests"
            case .active:   return "All Active Quests"
            case .complete: return "Completed Quests"
            }
        }
    }

    var body: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            // 1) Only the current page’s big title
            Text(selectedPage.title)
                .font(themeManager.theme.headingLargeFont)
                .foregroundColor(themeManager.theme.primaryColor)

            // 2) Sort toggle
            HStack {
                Spacer()
                Button {
                    ascending.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(themeManager.theme.bodySmallFont)
                        .rotationEffect(.degrees(ascending ? 0 : 180))
                        .foregroundColor(themeManager.theme.secondaryColor)
                }
            }
            .padding(.horizontal, themeManager.theme.paddingMedium)

            // 3) Paged TabView with dots
            TabView(selection: $selectedPage) {
                ForEach(Page.allCases, id: \.self) { page in
                    QuestList(page: page,
                              quests: quests(for: page),
                              now: now,
                              ascending: ascending,
                              vm: vm,
                              showDebuffMessage: $showDebuffMessage)
                    .tag(page)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 4) Debuff toast
            if showDebuffMessage {
                Text("Reinitiating Quest. Penalty Debuff Applied")
                    .font(themeManager.theme.bodyMediumFont)
                    .padding(.vertical, themeManager.theme.spacingMedium)
                    .padding(.horizontal, themeManager.theme.spacingLarge)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(themeManager.theme.cornerRadius)
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .padding()
        // Drive the live clock
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            now = time
        }
    }

    /// Helpers
    private func quests(for page: Page) -> [ActiveQuest] {
        let all = vm.activeQuests
        let todayInterval = Calendar.current.dateInterval(of: .day, for: now)!
        switch page {
        case .daily:
            return all.filter {
                $0.progress.status == .available
                  && todayInterval.contains($0.progress.expirationTime ?? .distantPast)
            }
        case .expired:
            return all.filter { $0.progress.status == .failed }
        case .active:
            return all.filter { $0.progress.status == .available }
        case .complete:
            return all.filter { $0.progress.status == .completed }
        }
    }
}

private struct QuestList: View {
    let page: MyQuestsView.Page
    let quests: [ActiveQuest]
    let now: Date
    let ascending: Bool
    let vm: MyQuestsViewModel
    @Binding var showDebuffMessage: Bool

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            if quests.isEmpty {
                Text(emptyMessage)
                    .font(themeManager.theme.bodySmallFont)
                    .foregroundColor(themeManager.theme.secondaryColor)
            } else {
                ForEach(sorted(quests)) { aq in
                    QuestRowView(
                        aq: aq,
                        now: now,
                        vm: vm,
                        showDebuffMessage: $showDebuffMessage
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private var emptyMessage: String {
        switch page {
        case .complete: return "No completed quests yet."
        default:         return "No quests here."
        }
    }

    private func sorted(_ list: [ActiveQuest]) -> [ActiveQuest] {
        list.sorted {
            let d1 = $0.progress.expirationTime ?? .distantPast
            let d2 = $1.progress.expirationTime ?? .distantPast
            return ascending ? d1 < d2 : d1 > d2
        }
    }
}
