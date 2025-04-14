//
//  ActiveSystemsViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ActiveSystemsViewModel: ObservableObject {
  @Published var activeSystems: [ActiveQuestSystem] = []
  @Published var errorMessage: String?

  private let db = Firestore.firestore()
  private let userQuestService = UserQuestService()
  private var listener: ListenerRegistration?

  deinit {
    listener?.remove()
  }

  /// Start listening to the current user's activeQuestSystems
  func startListening() {
    guard let uid = Auth.auth().currentUser?.uid else { return }
    listener = db
      .collection("users")
      .document(uid)
      .collection("activeQuestSystems")
      .addSnapshotListener { [weak self] snap, error in
        guard let self = self else { return }
        if let error = error {
          self.errorMessage = error.localizedDescription
          return
        }
        self.activeSystems = snap?.documents.compactMap { doc in
          try? doc.data(as: ActiveQuestSystem.self)
        } ?? []
      }
  }

  /// Pause (or resume) a system
  func togglePause(system: ActiveQuestSystem) {
    guard let id = system.id else { return }
    let newStatus: SystemAssignmentStatus = (system.status == .active)
      ? .paused
      : .active

    userQuestService.updateSystemStatus(aqsId: id, status: newStatus) { error in
      DispatchQueue.main.async {
        if let error = error {
          self.errorMessage = error.localizedDescription
        }
      }
    }
  }

  /// Stop a system completely
  func stop(system: ActiveQuestSystem) {
    guard let id = system.id else { return }
    userQuestService.updateSystemStatus(aqsId: id, status: .stopped) { error in
      DispatchQueue.main.async {
        if let error = error {
          self.errorMessage = error.localizedDescription
        }
      }
    }
  }
}