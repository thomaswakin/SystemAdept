//
//  ActiveSystemsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct ActiveSystemsView: View {
  @StateObject private var vm = ActiveSystemsViewModel()
  @State private var path: [ActiveQuestSystem] = []

  var body: some View {
    List(vm.activeSystems) { system in
      HStack {
        NavigationLink(value: system) {
          Text(system.questSystemName)
            .font(.headline)
        }
        Spacer()
        Button {
          vm.togglePause(system: system)
        } label: {
          Text(system.status == .active ? "Pause" : "Resume")
        }
        .buttonStyle(.bordered)
        Button {
          vm.stop(system: system)
        } label: {
          Text("Stop")
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(.vertical, 4)
    }
    .navigationTitle("My Systems")
    .navigationDestination(for: ActiveQuestSystem.self) { system in
      QuestQueueView(activeSystem: system)
    }
    .onAppear { path = [] }
    .alert(isPresented: Binding<Bool>(
      get: { vm.errorMessage != nil },
      set: { _ in vm.errorMessage = nil }
    )) {
      Alert(title: Text("Error"),
            message: Text(vm.errorMessage ?? ""),
            dismissButton: .default(Text("OK")))
    }
  }
}
