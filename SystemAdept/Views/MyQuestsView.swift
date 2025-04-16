//
//  MyQuestsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/15/25.
//

import SwiftUI

struct MyQuestsView: View {
    @StateObject private var vm = MyQuestsViewModel()
    @State private var filter: Filter = .all
    @State private var ascending = true

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case past = "Past"

        var id: String { rawValue }

        /// Only used for active‑quest filters:
        func matches(_ date: Date?) -> Bool {
            guard let date = date else { return false }
            let now = Date()
            switch self {
            case .all:
                return true
            case .today:
                return Calendar.current.isDate(date, inSameDayAs: now)
            case .week:
                return date >= now && date < Calendar.current.date(byAdding: .day, value: 7, to: now)!
            case .month:
                return date >= now && date < Calendar.current.date(byAdding: .month, value: 1, to: now)!
            case .past:
                return false  // handled separately
            }
        }
    }

    /// Applies filter + sort to the full quest list
    private var filteredAndSorted: [ActiveQuest] {
        let now = Date()
        let all = vm.activeQuests

        let filtered: [ActiveQuest] = {
            switch filter {
            case .past:
                // Completed quests only
                return all.filter { $0.progress.status == .completed }
            default:
                // Active quests only, then date filter
                return all.filter {
                    $0.progress.status == .available
                        && filter.matches($0.progress.expirationTime)
                }
            }
        }()

        // Sort by expirationTime
        return filtered.sorted {
            guard let d1 = $0.progress.expirationTime,
                  let d2 = $1.progress.expirationTime
            else { return false }
            return ascending ? (d1 < d2) : (d1 > d2)
        }
    }

    var body: some View {
        let now = Date()
        VStack {
            // Filter / Sort Bar
            HStack {
                ForEach(Filter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline)
                            .fontWeight(filter == f ? .bold : .regular)
                            .foregroundColor(filter == f ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    if f != Filter.allCases.last { Spacer() }
                }
                Spacer()
                Button {
                    ascending.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .rotationEffect(.degrees(ascending ? 0 : 180))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Quest List
            List {
                if let err = vm.errorMessage {
                    Text("Error: \(err)")
                        .foregroundColor(.red)
                }

                ForEach(filteredAndSorted) { aq in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(aq.quest.questName)
                                .font(.headline)
                            Spacer()
                            if aq.progress.status == .available {
                                Button("Complete") {
                                    vm.complete(aq)
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Text("Completed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text("System: \(aq.systemName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let exp = aq.progress.expirationTime {
                            let remaining = Int(exp.timeIntervalSince(now))
                            Text(remaining > 0
                                 ? "Expires in \(remaining)s"
                                 : "Expired")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if filteredAndSorted.isEmpty {
                    Text(filter == .past
                         ? "No completed quests yet."
                         : "No quests match “\(filter.rawValue)”")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Active Quests")
    }
}

struct MyQuestsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MyQuestsView()
        }
    }
}


