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
    @State private var ascending: Bool = true

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }
        func matches(_ date: Date?) -> Bool {
            guard let date = date else { return false }
            let now = Date()
            switch self {
            case .all: return true
            case .today: return Calendar.current.isDate(date, inSameDayAs: now)
            case .week: return date >= now && date < Calendar.current.date(byAdding: .day, value: 7, to: now)!
            case .month: return date >= now && date < Calendar.current.date(byAdding: .month, value: 1, to: now)!
            }
        }
    }

    private var filteredAndSorted: [ActiveQuest] {
        let now = Date()
        let filtered = vm.activeQuests.filter { aq in
            filter.matches(aq.progress.expirationTime)
        }
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
            // Filter + Sort Bar
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

            // Quest list
            List {
                if let err = vm.errorMessage {
                    Text("Error: \(err)")
                        .foregroundColor(.red)
                }

                ForEach(filteredAndSorted) { aq in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(aq.quest.questName)
                            .font(.headline)
                        Text("System: \(aq.systemName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            if let exp = aq.progress.expirationTime {
                                let remaining = Int(exp.timeIntervalSince(now))
                                Text(remaining > 0
                                     ? "Expires in \(remaining)s"
                                     : "Expired")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(aq.progress.status.rawValue.capitalized)
                                .font(.caption2)
                                .padding(4)
                                .background(Color(.secondarySystemFill))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if filteredAndSorted.isEmpty {
                    Text("No quests match “\(filter.rawValue)”")
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

