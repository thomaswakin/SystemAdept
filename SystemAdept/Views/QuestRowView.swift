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

    // MARK: - Completion Toast State
    @State private var showCompleteMessage = false
    @State private var completeAura: Double = 0

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: themeManager.theme.spacingSmall) {
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
                                // Calculate aura gain
                                let failed = Double(aq.progress.failedCount)
                                let debuff = aq.quest.questRepeatDebuffOverride ?? 1.0
                                let aura = aq.quest.questAuraGranted * pow(debuff, failed)
                                // Trigger completion toast
                                completeAura = aura
                                showCompleteMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showCompleteMessage = false
                                    vm.complete(aq)
                                }
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

                // Move Debuffs count immediately below buttons
                if aq.progress.failedCount > 0 {
                    Text("Debuffs: \(aq.progress.failedCount)")
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(.red)
                }

                Text("System: \(aq.systemName)")
                    .font(themeManager.theme.bodySmallFont)
                    .foregroundColor(themeManager.theme.secondaryColor)

                // Expiration or completion
                if aq.progress.status == .available,
                   let start = aq.progress.availableAt,
                   let expiry = aq.progress.expirationTime {
                    ExpiryCountdownView(start: start, expiry: expiry, now: now)
                        .padding(.top, themeManager.theme.spacingSmall / 2)
                } else if let comp = aq.progress.completedAt {
                    Text("Completed on \(comp.formatted(date: .abbreviated, time: .shortened))")
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(themeManager.theme.secondaryColor)
                        .padding(.top, themeManager.theme.spacingSmall / 2)
                }
            }
            .padding(themeManager.theme.paddingSmall)
            .background(Color.white.opacity(0.9))
            .cornerRadius(themeManager.theme.cornerRadius)

            // Completion toast overlay
            if showCompleteMessage {
                VStack(spacing: themeManager.theme.spacingSmall) {
                    Text("Quest Complete")
                        .font(themeManager.theme.headingSmallFont)
                        .foregroundColor(.white)
                    Text("Rewards: \(Int(completeAura)) Aura granted")
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(.white)
                }
                .padding(themeManager.theme.spacingMedium)
                .background(Color.black.opacity(0.7))
                .cornerRadius(themeManager.theme.cornerRadius)
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
