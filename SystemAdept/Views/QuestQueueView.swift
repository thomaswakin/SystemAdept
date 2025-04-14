//
//  QuestQueueView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import SwiftUI

struct QuestQueueView: View {
  let activeSystem: ActiveQuestSystem
  @StateObject private var vm = QuestQueueViewModel()

  // Alert state
  @State private var showCompletionAlert = false

  var body: some View {
    VStack(spacing: 20) {
      if let quest = vm.questDetail, let qp = vm.current {
        Text(quest.questName)
          .font(.title2).bold()
        Text(quest.questPrompt)
          .multilineTextAlignment(.center)
          .padding()

        Text("Status: \(qp.status.rawValue.capitalized)")
          .font(.subheadline)

        Text("Time left: \(Int(vm.countdown))s")
          .font(.headline)

        HStack(spacing: 40) {
          Button("Completed") {
            vm.completeCurrent()
          }
          .disabled(vm.countdown <= 0)

          Button("Pause") {
            vm.pauseCurrent()
          }
        }
      } else {
        Text("No quests available right now.")
          .foregroundColor(.gray)
      }
      Spacer()
    }
    .padding()
    .navigationTitle("Quest Queue")
    .onAppear {
      vm.start(for: activeSystem)
    }
    // Listen for the aura‑gain event to show the alert
    .onReceive(vm.$lastAuraGained.compactMap { $0 }) { aura in
      showCompletionAlert = true
    }
    .alert("Quest Complete!",
           isPresented: $showCompletionAlert) {
      Button("OK") { showCompletionAlert = false }
    } message: {
      if let aura = vm.lastAuraGained,
         let questName = vm.questDetail?.questName {
        Text("\"\(questName)\" completed.\nAura increased by \(aura).")
      }
    }
  }
}

