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
        NavigationStack(path: $path) {
            List {
                if let error = vm.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }

                ForEach(vm.activeSystems) { system in
                    HStack {
                        // Tapping the name pushes into QuestQueueView
                        NavigationLink(value: system) {
                            Text(system.questSystemName)
                                .font(.headline)
                        }

                        Spacer()

                        // Pause / Resume
                        Button {
                            vm.togglePause(system: system)
                        } label: {
                            Text(system.status == .active ? "Pause" : "Resume")
                        }
                        .buttonStyle(.bordered)

                        // Stop
                        Button {
                            vm.stop(system: system)
                        } label: {
                            Text("Stop")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("My Quest Systems")
            // Map ActiveQuestSystem → QuestQueueView
            .navigationDestination(for: ActiveQuestSystem.self) { system in
                QuestQueueView(activeSystem: system)
            }
            // Reset to root whenever you come back to this tab
            .onAppear {
                path = []
            }
        }
    }
}

struct ActiveSystemsView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveSystemsView()
    }
}
