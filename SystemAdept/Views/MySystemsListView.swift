//
//  MySystemsListView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/24/25.
//


import SwiftUI

struct MySystemsListView: View {
    @StateObject private var vm = ActiveSystemsViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var path: [ActiveQuestSystem] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(vm.activeSystems) { system in
                HStack {
                    // Use a Button to push onto the path
                    Button {
                        path.append(system)
                    } label: {
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
                .padding(.vertical, themeManager.theme.spacingSmall)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)   // iOS 16+
            .background(Color.clear)
            .navigationTitle("My Systems")
            // map path entries to destination views
            .navigationDestination(for: ActiveQuestSystem.self) { system in
                QuestQueueView(activeSystem: system)
            }
            .onAppear { path = [] }
            .alert(isPresented: Binding<Bool>(
                get: { vm.errorMessage != nil },
                set: { _ in vm.errorMessage = nil }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(vm.errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .background(Color.clear) // ensure NavigationStack has no white background
    }
}

struct MySystemsListView_Previews: PreviewProvider {
    static var previews: some View {
        MySystemsListView()
            .environmentObject(ThemeManager())
    }
}
