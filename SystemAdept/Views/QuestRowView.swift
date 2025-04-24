//
//  QuestRowView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/23/25.
//


import SwiftUI

/// A single row representing an ActiveQuest in MyQuestsView,
/// extracted to reduce MyQuestsView body complexity.
struct QuestRowView: View {
    let aq: ActiveQuest
    let now: Date
    @ObservedObject var vm: MyQuestsViewModel
    @Binding var showDebuffMessage: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(aq.quest.questName)
                    .font(themeManager.theme.headingMediumFont)
                    .foregroundColor(themeManager.theme.primaryColor)
                Spacer()
                // Action buttons
                if aq.progress.status == .available {
                    if let exp = aq.progress.expirationTime, exp < now {
                        Button("Restart") {
                            vm.restart(aq) { success in
                                if success {
                                    showDebuffMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showDebuffMessage = false
                                    }
                                }
                            }
                        }
                        .font(themeManager.theme.bodySmallFont)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("Complete") {
                            vm.complete(aq)
                        }
                        .font(themeManager.theme.bodySmallFont)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else if aq.progress.status == .failed {
                    Button("Restart") {
                        vm.restart(aq) { success in
                            if success {
                                showDebuffMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showDebuffMessage = false
                                }
                            }
                        }
                    }
                    .font(themeManager.theme.bodySmallFont)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text("Completed")
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(themeManager.theme.secondaryColor)
                }
            }

            Text("System: \(aq.systemName)")
                .font(themeManager.theme.bodySmallFont)
                .foregroundColor(themeManager.theme.secondaryColor)

            // Expiration or completion
            if aq.progress.status == .available,
               let start = aq.progress.availableAt,
               let expiry = aq.progress.expirationTime {
                ExpiryCountdownView(start: start, expiry: expiry, now: now)
            } else if let comp = aq.progress.completedAt {
                Text("Completed on \(comp.formatted(date: .abbreviated, time: .shortened))")
                    .font(themeManager.theme.bodySmallFont)
                    .foregroundColor(themeManager.theme.secondaryColor)
            }

            if aq.progress.failedCount > 0 {
                Text("Debuffs: \(aq.progress.failedCount)")
                    .font(themeManager.theme.bodySmallFont)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, themeManager.theme.paddingSmall)
    }
}
