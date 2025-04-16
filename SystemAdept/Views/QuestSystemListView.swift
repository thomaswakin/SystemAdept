//
//  QuestSystemListView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct QuestSystemListView: View {
  @StateObject private var viewModel = QuestSystemListViewModel()

  var body: some View {
    ZStack {
      List(viewModel.systems) { system in
        HStack {
          Text(system.name)
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
          }
          .disabled(viewModel.ineligibleSystemIds.contains(system.id ?? ""))
        }
        .padding(.vertical, 4)
      }
      .opacity(viewModel.isLoading ? 0.3 : 1)

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
