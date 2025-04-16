//
//  QuestSystemListViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseFirestore
import Combine

final class QuestSystemListViewModel: ObservableObject {
    @Published var systems: [QuestSystem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var ineligibleSystemIds: Set<String> = []

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    /// Load all quest systems from Firestore.
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
                guard let docs = snapshot?.documents else { return }

                // Manual decode each QuestSystem
                self.systems = docs.compactMap { doc in
                    QuestSystem(from: doc)
                }
            }
    }

    /// When the user selects a system, assign it via UserQuestService.
    func select(system: QuestSystem) {
        isLoading = true
        UserQuestService().assignSystem(systemId: system.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    // Mark this system as ineligible until completed/stopped
                    self.ineligibleSystemIds.insert(system.id)
                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }
}
