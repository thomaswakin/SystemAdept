//
//  QuestSystemListViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

final class QuestSystemListViewModel: ObservableObject {
  @Published var systems: [QuestSystem] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  
  /// Systems the user cannot select right now
  @Published var ineligibleSystemIds: Set<String> = []

  private let db = Firestore.firestore()
  private let userQuestService = UserQuestService()

  func loadSystems() {
    isLoading = true
    db.collection("questSystems")
      .getDocuments { snap, error in
        DispatchQueue.main.async {
          self.isLoading = false
          print("got systems:", snap?.documents.count ?? 0, error as Any)
          if let error = error {
            self.errorMessage = error.localizedDescription
            return
          }
          self.systems = snap?.documents.compactMap { doc in
            do {
              return try doc.data(as: QuestSystem.self)
            } catch {
              print("⚠️ decode error \(doc.documentID): \(error)")
              return nil
            }
          } ?? []
          
          // After loading systems, compute eligibility
          self.loadEligibility()
        }
      }
  }

  func select(system: QuestSystem) {
    guard let systemId = system.id else {
      self.errorMessage = "Invalid system ID"
      return
    }
    // Double-check eligibility before assigning
    guard !ineligibleSystemIds.contains(systemId) else {
      self.errorMessage = "You already have an active \(system.name) system."
      return
    }

    userQuestService.assignSystem(systemId: systemId) { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          // Recompute eligibility so this system becomes ineligible until completed
          self.loadEligibility()
        case .failure(let error):
          self.errorMessage = error.localizedDescription
        }
      }
    }
  }

  /// Load all the user’s activeQuestSystems and mark those ineligible
  private func loadEligibility() {
    guard let uid = Auth.auth().currentUser?.uid else { return }

    db.collection("users")
      .document(uid)
      .collection("activeQuestSystems")
      .getDocuments { snap, error in
        if let error = error {
          print("Error loading activeQuestSystems:", error)
          return
        }
        let docs = snap?.documents ?? []
        var ineligible = Set<String>()
        for doc in docs {
          let data = doc.data()
          guard
            let ref = data["questSystemRef"] as? DocumentReference,
            let status = data["status"] as? String
          else { continue }
          // If any non-completed instance exists, mark system ineligible
          if status != SystemAssignmentStatus.completed.rawValue,
             let sysId = ref.documentID as String? {
            ineligible.insert(sysId)
          }
        }
        DispatchQueue.main.async {
          self.ineligibleSystemIds = ineligible
        }
      }
  }
}
