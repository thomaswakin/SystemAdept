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
  @EnvironmentObject private var themeManager: ThemeManager

  var body: some View {
    List(vm.activeSystems) { system in
      HStack {
        NavigationLink(value: system) {
          Text(system.questSystemName)
            .font(themeManager.theme.bodyMediumFont)
        }
        Spacer()
        Button {
          vm.togglePause(system: system)
        } label: {
          Text(system.status == .active ? "Pause" : "Resume")
                .font(themeManager.theme.bodyMediumFont)
        }
        .buttonStyle(.bordered)
        Button {
          vm.stop(system: system)
        } label: {
          Text("Stop")
                .font(themeManager.theme.bodyMediumFont)
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(.vertical, 4)
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)  // iOS 16+
    .background(Color.clear)
    .navigationTitle("")
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
