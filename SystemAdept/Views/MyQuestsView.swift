//
//  MyQuestsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/15/25.
//

import SwiftUI

// MARK: - Countdown Formatting Helpers

fileprivate func timeRemainingText(until expiry: Date) -> String {
    let interval = expiry.timeIntervalSinceNow
    guard interval > 0 else { return "Expired" }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.year, .month, .day, .hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    formatter.zeroFormattingBehavior = .dropAll

    return formatter.string(from: interval) ?? ""
}

fileprivate func expirationColor(for expiry: Date) -> Color {
    let remain = expiry.timeIntervalSinceNow
    if remain <= 0 {
        return .gray
    } else if remain < 3600 {
        return .red
    } else if remain < 86_400 {
        return .orange
    } else {
        return .green
    }
}

/// A self‑contained view that shows a live countdown from `now` between `start`→`expiry`.
struct ExpiryCountdownView: View {
    let start: Date
    let expiry: Date
    let now: Date

    private var total: TimeInterval { expiry.timeIntervalSince(start) }
    private var remaining: TimeInterval { max(0, expiry.timeIntervalSince(now)) }
    private var label: String { timeRemainingText(until: expiry) }

    /// Choose color: gray if expired, red if ≤10% remaining, orange if <1 h, else green
    private var color: Color {
        if remaining <= 0 {
            return .gray
        } else if remaining < total * 0.1 {
            return .red
        } else if remaining < 3600 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        Text("Expires in \(label)")
          .font(.caption2)
          .monospacedDigit()
          .foregroundColor(color)
    }
}

struct MyQuestsView: View {
    @StateObject private var vm = MyQuestsViewModel()
    @State private var filter: Filter = .all
    @State private var ascending = true
    @State private var showDebuffMessage = false
    @State private var now = Date()

    private enum Filter: String, CaseIterable, Identifiable {
        case all      = "All"
        case today    = "Today"
        case complete = "Complete"

        var id: String { rawValue }

        /// Determines if a given date matches the filter criteria.
        func matches(_ date: Date?) -> Bool {
            guard let date = date else { return false }
            let now = Date()

            switch self {
            case .all:
                // include all active (available) and expired (failed).
                return true
            case .today:
                // only those expiring today
                return Calendar.current.isDate(date, inSameDayAs: now)
            case .complete:
                // not used, completed quests handled separately
                return false
            }
        }
    }

    /// Applies the current filter and sort settings to the quest list.
    private var filteredAndSorted: [ActiveQuest] {
        let all = vm.activeQuests
        let filtered: [ActiveQuest] = {
            switch filter {
            case .complete:
                return all.filter { $0.progress.status == .completed }
            default:
                return all.filter {
                    ( $0.progress.status == .available
                    || $0.progress.status == .failed )
                    && filter.matches($0.progress.expirationTime)
                }
            }
        }()

        return filtered.sorted { a, b in
            let d1: Date
            let d2: Date
            if filter == .complete {
                d1 = a.progress.completedAt    ?? Date.distantPast
                d2 = b.progress.completedAt    ?? Date.distantPast
            } else {
                d1 = a.progress.expirationTime ?? Date.distantPast
                d2 = b.progress.expirationTime ?? Date.distantPast
            }
            return ascending ? (d1 < d2) : (d1 > d2)
        }
    }

    var body: some View {
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
                                } else if aq.progress.status == .failed {
                                    Button("Restart") {
                                        vm.restart(aq) { success in
                                            if success {
                                                withAnimation { showDebuffMessage = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                    withAnimation { showDebuffMessage = false }
                                                }
                                            }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
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
                            if filter == .complete {
                                if let comp = aq.progress.completedAt {
                                    Text("Completed on \(comp.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            } else if aq.progress.status == .available {
                                if let start = aq.progress.availableAt,
                                   let expiry = aq.progress.expirationTime
                                {
                                    ExpiryCountdownView(start: start, expiry: expiry, now: now)
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
                        Text(filter == .complete
                            ? "No completed quests yet."
                            : "No quests match “\(filter.rawValue)”")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .listStyle(.plain)
            }

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
        .onReceive(
          Timer.publish(every: 1, on: .main, in: .common)
               .autoconnect()
        ) { time in
          self.now = time
        }
    }
}
