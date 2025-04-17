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
    @State private var showDebuffMessage = false

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case past = "Past"

        var id: String { rawValue }
        func matches(_ date: Date?) -> Bool {
            guard let date = date else { return false }
            let now = Date()
            switch self {
            case .all: return true
            case .today: return Calendar.current.isDate(date, inSameDayAs: now)
            case .week: return date >= now && date < Calendar.current.date(byAdding: .day, value: 7, to: now)!
            case .month: return date >= now && date < Calendar.current.date(byAdding: .month, value: 1, to: now)!
            case .past: return false
            }
        }
    }

    private var filteredAndSorted: [ActiveQuest] {
        let all = vm.activeQuests
        let filtered: [ActiveQuest] = {
            switch filter {
            case .past:
                return all.filter { $0.progress.status == .completed }
            default:
                return all.filter {
                    $0.progress.status == .available && filter.matches($0.progress.expirationTime)
                }
            }
        }()
        return filtered.sorted { a, b in
            let d1 = (filter == .past ? a.progress.completedAt : a.progress.expirationTime) ?? Date.distantPast
            let d2 = (filter == .past ? b.progress.completedAt : b.progress.expirationTime) ?? Date.distantPast
            return ascending ? (d1 < d2) : (d1 > d2)
        }
    }

    var body: some View {
        let now = Date()
        ZStack {
            VStack {
                // Filter + Sort Bar
                HStack {
                    ForEach(Filter.allCases) { f in
                        Button { filter = f } label: {
                            Text(f.rawValue)
                                .font(.subheadline)
                                .fontWeight(filter == f ? .bold : .regular)
                                .foregroundColor(filter == f ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                        if f != Filter.allCases.last { Spacer() }
                    }
                    Spacer()
                    Button { ascending.toggle() } label: {
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
                                    if let exp = aq.progress.expirationTime, exp < now {
                                        Button("Restart") {
                                            vm.restart(aq) { success in
                                                if success {
                                                    withAnimation {
                                                        showDebuffMessage = true
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                        withAnimation {
                                                            showDebuffMessage = false
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else {
                                        Button("Complete") {
                                            vm.complete(aq)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                } else {
                                    Text("Completed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text("System: \(aq.systemName)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Show expiration or completion
                            if filter == .past {
                                if let comp = aq.progress.completedAt {
                                    Text("Completed on \(comp.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            } else if aq.progress.status == .available {
                                if let exp = aq.progress.expirationTime {
                                    let remaining = Int(exp.timeIntervalSince(now))
                                    Text(remaining > 0 ? "Expires in \(remaining)s" : "Expired")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }

                            // Debuff count for both expired and past
                            if aq.progress.failedCount > 0 {
                                Text("Debuffs: \(aq.progress.failedCount)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if filteredAndSorted.isEmpty {
                        Text(filter == .past ? "No completed quests yet." : "No quests match “\(filter.rawValue)”")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .listStyle(.plain)
            }

            // Overlay message
            if showDebuffMessage {
                Text("Reinitiating Quest. Penalty Debuff Applied")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .navigationTitle("Active Quests")
    }
}


