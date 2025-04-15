//
//  ActiveSystemsViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class ActiveSystemsViewModel: ObservableObject {
    @Published var activeSystems: [ActiveQuestSystem] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    private func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let coll = db
            .collection("users")
            .document(uid)
            .collection("activeQuestSystems")

        listener = coll.addSnapshotListener { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            let docs = snap?.documents ?? []
            print("🔍 ActiveSystems listener fired. docs.count =", docs.count)
            for doc in docs {
                let status = doc.data()["status"] as? String ?? "–"
                print("   • aqsId:", doc.documentID, "status:", status)
            }

            self.activeSystems = docs.compactMap { doc in
                do {
                    return try doc.data(as: ActiveQuestSystem.self)
                } catch {
                    print("⚠️ Failed to decode AQS \(doc.documentID):", error)
                    return nil
                }
            }
        }
    }

    func togglePause(system: ActiveQuestSystem) {
        guard let id = system.id else { return }
        let newStatus: SystemAssignmentStatus = (system.status == .active) ? .paused : .active
        updateStatus(aqsId: id, status: newStatus)
    }

    func stop(system: ActiveQuestSystem) {
        guard let id = system.id else { return }
        updateStatus(aqsId: id, status: .stopped)
    }

    private func updateStatus(aqsId: String, status: SystemAssignmentStatus) {
        let ref = db
            .collection("users")
            .document(Auth.auth().currentUser!.uid)
            .collection("activeQuestSystems")
            .document(aqsId)

        ref.updateData(["status": status.rawValue]) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
