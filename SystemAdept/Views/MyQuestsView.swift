//
//  MyQuestsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct MyQuestsView: View {
    @StateObject private var vm = MyQuestsViewModel()
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    // Pager state
    @State private var selectedPage: Page
    @State private var ascending = true
    @State private var now = Date()
    @State private var showDebuffMessage = false

    init(initialPage: Page = .daily) {
        _selectedPage = State(initialValue: initialPage)
    }

    enum Page: Int, CaseIterable {
        case daily, active, expired, complete
        var title: String {
            switch self {
            case .daily:    return "Daily Quests"
            case .active:   return "All Active Quests"
            case .expired:  return "Expired Quests"
            case .complete: return "Completed Quests"
            }
        }
    }

    var body: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Text(selectedPage.title)
                .font(themeManager.theme.headingLargeFont)
                .foregroundColor(themeManager.theme.primaryColor)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(themeManager.theme.overlayBackground)
                .cornerRadius(themeManager.theme.cornerRadius)
                .padding(.horizontal, themeManager.theme.paddingMedium)

            HStack {
                Spacer()
                Button { ascending.toggle() } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(themeManager.theme.bodySmallFont)
                        .rotationEffect(.degrees(ascending ? 0 : 180))
                        .foregroundColor(themeManager.theme.secondaryColor)
                }
            }
            .padding(.horizontal, themeManager.theme.paddingMedium)

            TabView(selection: $selectedPage) {
                ForEach(Page.allCases, id: \.self) { page in
                    QuestList(
                        page: page,
                        quests: quests(for: page),
                        now: now,
                        ascending: ascending,
                        vm: vm,
                        showDebuffMessage: $showDebuffMessage,
                        selectedPage: $selectedPage
                    )
                    .tag(page)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            now = time
        }
    }

    /// Helpers
    private func quests(for page: Page) -> [ActiveQuest] {
        let all = vm.activeQuests

        switch page {
        case .daily:
            // Show quests due within 24h + rest period length
            let nowDate = now
            let cal = Calendar.current

            // User's rest period
            let startHour   = authVM.userProfile?.restStartHour   ?? 22
            let startMinute = authVM.userProfile?.restStartMinute ?? 0
            let endHour     = authVM.userProfile?.restEndHour     ?? 6
            let endMinute   = authVM.userProfile?.restEndMinute   ?? 0

            // Most recent rest start
            let startComp = DateComponents(hour: startHour, minute: startMinute)
            let restStart = cal.nextDate(
                after: nowDate,
                matching: startComp,
                matchingPolicy: .nextTime,
                direction: .backward
            ) ?? nowDate

            // Next rest end
            let endComp = DateComponents(hour: endHour, minute: endMinute)
            let restEnd = cal.nextDate(
                after: restStart,
                matching: endComp,
                matchingPolicy: .nextTime,
                direction: .forward
            ) ?? restStart.addingTimeInterval(8*3600)

            let restLength = restEnd.timeIntervalSince(restStart)
            let cutoff = nowDate.addingTimeInterval(24*3600 + restLength)

            return all.filter {
                $0.progress.status == .available
                && ($0.progress.expirationTime ?? .distantFuture) <= cutoff
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
    @Binding var selectedPage: MyQuestsView.Page

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            if quests.isEmpty {
                let failedCount = vm.activeQuests.filter { $0.progress.status == .failed }.count
                if (page == .daily || page == .active) && failedCount > 0 {
                    Button(action: { selectedPage = .expired }) {
                        Text("\(failedCount) quests awaiting restart")
                            .font(themeManager.theme.bodySmallFont)
                            .italic()
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    Text(emptyStateMessage)
                        .font(themeManager.theme.bodySmallFont)
                        .italic()
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
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

    private var emptyStateMessage: String {
        switch page {
        case .complete: return "No quests completed"
        default: return "Waiting on quests"
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
