//
//  QuestSystemListViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class QuestSystemListViewModel: ObservableObject {
    @Published var systems: [QuestSystem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var ineligibleSystemIds: Set<String> = []

    private let db = Firestore.firestore()

    init() {
        loadActiveSystemIds()
        loadSystems()
    }

    /// Fetch global quest systems.
    func loadSystems() {
        isLoading = true
        db.collection("questSystems")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                let docs = snapshot?.documents ?? []
                self.systems = docs.compactMap { QuestSystem(from: $0) }
            }
    }

    /// Fetch the user's currently active/paused systems to disable re‑adding.
    func loadActiveSystemIds() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users")
          .document(uid)
          .collection("activeQuestSystems")
          .getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error loading active systems:", error)
                return
            }
            let docs = snapshot?.documents ?? []
            let ids = docs.filter { doc in
                let status = doc.data()["status"] as? String ?? ""
                return status != SystemAssignmentStatus.completed.rawValue
                    && status != SystemAssignmentStatus.stopped.rawValue
            }
            .compactMap { doc in
                (doc.data()["questSystemRef"] as? DocumentReference)?.documentID
            }
            self.ineligibleSystemIds = Set(ids)
        }
    }

    /// Assign a new system to the user.
    func select(system: QuestSystem) {
        isLoading = true
        UserQuestService().assignSystem(systemId: system.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    // Prevent re‑adding until this system is completed/stopped
                    self.ineligibleSystemIds.insert(system.id)
                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }
}
