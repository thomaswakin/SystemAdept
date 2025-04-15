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

            self.activeSystems = docs.compactMap { doc in
                let data = doc.data()
                // Required fields
                guard
                    let qsr = data["questSystemRef"] as? DocumentReference,
                    let statusStr = data["status"] as? String,
                    let status = SystemAssignmentStatus(rawValue: statusStr),
                    let ts = data["assignedAt"] as? Timestamp
                else {
                    print("⚠️ Missing fields in AQS \(doc.documentID)")
                    return nil
                }

                // Optional or mixed‑type fields
                let name = data["questSystemName"] as? String ?? qsr.documentID
                let isUserSelected: Bool = {
                    if let b = data["isUserSelected"] as? Bool { return b }
                    if let i = data["isUserSelected"] as? Int  { return i != 0 }
                    return false
                }()
                let currentQ = data["currentQuestRef"] as? DocumentReference

                return ActiveQuestSystem(
                    id: doc.documentID,
                    questSystemRef: qsr,
                    questSystemName: name,
                    isUserSelected: isUserSelected,
                    assignedAt: ts.dateValue(),
                    status: status,
                    currentQuestRef: currentQ
                )
            }
        }
    }

    func togglePause(system: ActiveQuestSystem) {
        let newStatus: SystemAssignmentStatus = (system.status == .active) ? .paused : .active
        updateStatus(aqsId: system.id, status: newStatus)
    }

    func stop(system: ActiveQuestSystem) {
        updateStatus(aqsId: system.id, status: .stopped)
    }

    private func updateStatus(aqsId: String, status: SystemAssignmentStatus) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db
            .collection("users")
            .document(uid)
            .collection("activeQuestSystems")
            .document(aqsId)

        ref.updateData(["status": status.rawValue]) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
