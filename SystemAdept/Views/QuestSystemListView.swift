//
//  QuestSystemListView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct QuestSystemListView: View {
  @StateObject private var viewModel = QuestSystemListViewModel()
  @EnvironmentObject private var themeManager: ThemeManager

  var body: some View {
    ZStack {
      List(viewModel.systems) { system in
        HStack {
          Text(system.name)
                .font(themeManager.theme.bodyMediumFont)
          Spacer()
          Button {
            viewModel.select(system: system)
          } label: {
            Text("Select")
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(viewModel.ineligibleSystemIds.contains(system.id ?? "")
                          ? Color.gray.opacity(0.2)
                          : Color.blue.opacity(0.2))
              .cornerRadius(8)
              .font(themeManager.theme.bodyMediumFont)
          }
          .disabled(viewModel.ineligibleSystemIds.contains(system.id ?? ""))
        }
        .padding(.vertical, 4)
      }
      .scrollContentBackground(.hidden)  // iOS 16+
      .background(Color.clear)
      .opacity(viewModel.isLoading ? 0.3 : 1)
      .listStyle(.plain)


      if viewModel.isLoading {
        ProgressView("Loading systems…")
          .padding()
          .background(Color(.systemBackground))
          .cornerRadius(10)
          .shadow(radius: 5)
      }
    }
    .navigationTitle("Available Systems")
    .onAppear { viewModel.loadSystems() }
    .alert(isPresented: Binding<Bool>(
      get: { viewModel.errorMessage != nil },
      set: { _ in viewModel.errorMessage = nil }
    )) {
      Alert(title: Text("Error"),
            message: Text(viewModel.errorMessage ?? ""),
            dismissButton: .default(Text("OK")))
    }
  }
}
