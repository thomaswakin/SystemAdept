//
//  ActiveSystemsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import SwiftUI

struct ActiveSystemsView: View {
    @StateObject private var viewModel = ActiveSystemsViewModel()

    var body: some View {
        NavigationView {
            List {
                // Show any errors
                if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }

                // One row per active quest system
                ForEach(viewModel.activeSystems) { system in
                    NavigationLink(destination: QuestQueueView(activeSystem: system)) {
                        HStack {
                            // Display the system ID (you can swap to a fetched name later)
                            Text(system.questSystemRef.documentID)
                                .font(.headline)

                            Spacer()

                            // Current assignment status
                            Text(system.status.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            // Pause / Resume button
                            Button(action: {
                                viewModel.togglePause(system: system)
                            }) {
                                Text(system.status == .active ? "Pause" : "Resume")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Stop button
                            Button(action: {
                                viewModel.stop(system: system)
                            }) {
                                Text("Stop")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("My Quest Systems")
            .onAppear {
                viewModel.startListening()
            }
        }
    }
}

struct ActiveSystemsView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveSystemsView()
    }
}
