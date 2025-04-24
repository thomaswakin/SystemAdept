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
    @State private var filter: QuestFilter = .all
    @State private var ascending = true
    @State private var showDebuffMessage = false
    @State private var now = Date()

    // MARK: – Computed Subviews

    private var filterBar: some View {
        HStack {
            ForEach(QuestFilter.allCases) { f in
                Button { filter = f } label: {
                    Text(f.rawValue)
                        .font(themeManager.theme.bodySmallFont)
                        .fontWeight(filter == f ? .bold : .regular)
                        .foregroundColor(filter == f
                            ? themeManager.theme.accentColor
                            : themeManager.theme.primaryColor)
                }
                .buttonStyle(.plain)
                if f != QuestFilter.allCases.last { Spacer() }
            }
            Spacer()
            Button { ascending.toggle() } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(themeManager.theme.bodySmallFont)
                    .rotationEffect(.degrees(ascending ? 0 : 180))
                    .foregroundColor(themeManager.theme.secondaryColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, themeManager.theme.paddingMedium)
        .padding(.top, themeManager.theme.paddingMedium)
    }

    private var questList: some View {
        List {
            if let err = vm.errorMessage {
                Text("Error: \(err)")
                    .font(themeManager.theme.bodySmallFont)
                    .foregroundColor(.red)
            } else if vm.filteredAndSorted(filter: filter, ascending: ascending).isEmpty {
                Text(emptyMessage)
                    .font(themeManager.theme.bodySmallFont)
                    .foregroundColor(themeManager.theme.secondaryColor)
            } else {
                ForEach(vm.filteredAndSorted(filter: filter, ascending: ascending)) { aq in
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

    @ViewBuilder
    private var overlayMessage: some View {
        if showDebuffMessage {
            Text("Reinitiating Quest. Penalty Debuff Applied")
                .font(themeManager.theme.bodyMediumFont)
                // add more breathing room inside the bubble…
                .padding(.vertical, themeManager.theme.paddingMedium)
                .padding(.horizontal, themeManager.theme.paddingLarge)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(themeManager.theme.cornerRadius)
                .shadow(radius: 4)
                // and a little padding from the screen edges
                .padding(themeManager.theme.paddingMedium)
                .transition(.opacity)
                .zIndex(1)
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .complete:
            return "No completed quests yet."
        default:
            return "No quests match “\(filter.rawValue)”"
        }
    }

    var body: some View {
        ZStack {
            VStack() {
                filterBar
                questList
            }
            overlayMessage
        }
        .navigationTitle("Active Quests")
        .font(themeManager.theme.headingLargeFont)
        .foregroundColor(themeManager.theme.primaryColor)
        .padding()
        .onReceive(
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        ) { time in
            now = time
        }
    }
}


