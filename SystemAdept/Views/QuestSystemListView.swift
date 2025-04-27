//
//  QuestSystemListView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

/// Lists all available quest systems and allows selecting one to activate.
struct QuestSystemListView: View {
    @StateObject private var viewModel = QuestSystemListViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    // Toast state
    @State private var showActivationMessage = false
    @State private var activatedSystemName = ""

    var body: some View {
        ZStack {
            VStack(spacing: themeManager.theme.spacingMedium) {
                // List of systems
                List(viewModel.systems) { system in
                    // Whole row is tappable
                    Button {
                        activate(system)
                    } label: {
                        HStack {
                            Text(system.name)
                                .font(themeManager.theme.bodyMediumFont)
                                .foregroundColor(themeManager.theme.primaryTextColor)
                            Spacer()
                            Text("Activate System")
                                .font(themeManager.theme.bodySmallFont)
                                .foregroundColor(themeManager.theme.secondaryTextColor)
                                .padding(.horizontal, themeManager.theme.spacingMedium)
                                .padding(.vertical, themeManager.theme.spacingSmall / 2)
                                .background(themeManager.theme.accentColor.opacity(0.4))
                                .cornerRadius(themeManager.theme.cornerRadius)
                        }
                        .padding(.vertical, themeManager.theme.spacingSmall)
                    }
                    .listRowBackground(Color.white.opacity(0.9))
                    .buttonStyle(.plain)
                    .disabled(viewModel.ineligibleSystemIds.contains(system.id ?? ""))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Loading overlay
                if viewModel.isLoading {
                    ProgressView("Loading systems…")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(themeManager.theme.cornerRadius)
                        .shadow(radius: 5)
                }
            }
            .onAppear {
                viewModel.loadSystems()
            }

            // Activation toast overlay
            if showActivationMessage {
                Text("\(activatedSystemName) System activated. New Quests have been assigned.")
                    .font(themeManager.theme.bodyMediumFont)
                    .foregroundColor(themeManager.theme.secondaryTextColor)
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
    }

    private func activate(_ system: QuestSystem) {
        viewModel.select(system: system)
        activatedSystemName = system.name
        withAnimation {
            showActivationMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showActivationMessage = false
            }
        }
    }
}

struct QuestSystemListView_Previews: PreviewProvider {
    static var previews: some View {
        QuestSystemListView()
            .environmentObject(ThemeManager())
    }
}
