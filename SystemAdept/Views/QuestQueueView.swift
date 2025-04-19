//
//  QuestQueueView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct QuestQueueView: View {
    let activeSystem: ActiveQuestSystem
    @StateObject private var viewModel: QuestQueueViewModel
    @State private var showCompletionAlert = false

    init(activeSystem: ActiveQuestSystem) {
        self.activeSystem = activeSystem
        _viewModel = StateObject(
            wrappedValue: QuestQueueViewModel(activeSystem: activeSystem)
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            if let qp = viewModel.current,
               let quest = viewModel.questDetail
            {
                switch qp.status {
                case .available:
                    availableQuestView(quest: quest)
                case .failed:
                    failedQuestView(quest: quest, progress: qp)
                default:
                    noQuestView()
                }
            } else {
                noQuestView()
            }
        }
        .padding()
        .onAppear { viewModel.refreshAvailableQuests() }
    }

    @ViewBuilder
    private func availableQuestView(quest: Quest) -> some View {
        VStack(spacing: 16) {
            Text(quest.questName)
                .font(.title2).bold()
            Text(quest.questPrompt)
                .multilineTextAlignment(.center)
            Text("Time left: \(Int(viewModel.countdown))s")
                .font(.headline)
            Button("Completed") {
                viewModel.completeCurrent()
                showCompletionAlert = true
            }
            .buttonStyle(.borderedProminent)
        }
        .alert("Quest Complete!", isPresented: $showCompletionAlert) {
            Button("OK", role: .cancel) {
                showCompletionAlert = false
            }
        } message: {
            Text("\"\(quest.questName)\" completed.")
        }
    }

    @ViewBuilder
    private func failedQuestView(
        quest: Quest,
        progress: QuestProgress
    ) -> some View {
        VStack(spacing: 16) {
            Text(quest.questName)
                .font(.title2).bold()
                .foregroundColor(.red)
            Text("This quest has expired.")
                .foregroundColor(.secondary)
            Text("Debuff count: \(progress.failedCount)")
                .font(.subheadline)
            Button("Restart Quest") {
                viewModel.restartCurrent()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func noQuestView() -> some View {
        Text("No available quests")
            .foregroundColor(.secondary)
    }
}
