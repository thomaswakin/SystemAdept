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

/// Manages the list of quest systems the user has activated,
/// and triggers automatic quest‑unlocking refresh for each.
final class ActiveSystemsViewModel: ObservableObject {
    // MARK: - Published
    @Published var activeSystems: [ActiveQuestSystem] = []
    @Published var errorMessage: String?

    // MARK: - Private
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    /// Hold onto each QuestQueueViewModel so its periodicTimer isn't deallocated
    private var queueVMs: [String: QuestQueueViewModel] = [:]

    // MARK: - Init / Deinit
    init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Listen for Active Systems
    private func startListening() {
        print("ActiveSystemVM: starting activeSystems listener...")
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
            print("🔍 ActiveSystems listener fired. docs.count = \(docs.count)")

            // Map Firestore documents into ActiveQuestSystem
            var newSystems: [ActiveQuestSystem] = []
            for doc in docs {
                let data = doc.data()
                guard
                    let qsr       = data["questSystemRef"]   as? DocumentReference,
                    let statusStr = data["status"]           as? String,
                    let status    = SystemAssignmentStatus(rawValue: statusStr),
                    let ts        = data["assignedAt"]       as? Timestamp
                else {
                    print("⚠️ Missing fields in activeQuestSystems/\(doc.documentID)")
                    continue
                }

                let name = data["questSystemName"] as? String ?? qsr.documentID
                let isSelected: Bool = {
                    if let b = data["isUserSelected"] as? Bool { return b }
                    if let i = data["isUserSelected"] as? Int  { return i != 0 }
                    return false
                }()
                let currentQuestRef = data["currentQuestRef"] as? DocumentReference

                newSystems.append(
                    ActiveQuestSystem(
                        id: doc.documentID,
                        questSystemRef:   qsr,
                        questSystemName:  name,
                        isUserSelected:   isSelected,
                        assignedAt:       ts.dateValue(),
                        status:           status,
                        currentQuestRef:  currentQuestRef
                    )
                )
            }

            self.activeSystems = newSystems

            // ─── Trigger refresh/unlock for each active system ───
            print("🛠️ ActiveSystemsViewModel: running quest‑refresh for each system")
            for aqs in newSystems {
                print("🔄 Refreshing quests for \(aqs.questSystemName) (aqsId=\(aqs.id))")
                if let vm = self.queueVMs[aqs.id] {
                    // already exists: just refresh
                    vm.refreshAvailableQuests()
                } else {
                    // create & store so its periodicTimer sticks around
                    let vm = QuestQueueViewModel(activeSystem: aqs)
                    self.queueVMs[aqs.id] = vm
                    vm.refreshAvailableQuests()
                }
            }

            // Remove any VMs for systems the user deactivated
            let activeIds = Set(newSystems.map { $0.id })
            let removedIds = queueVMs.keys.filter { !activeIds.contains($0) }
            for id in removedIds {
                queueVMs.removeValue(forKey: id)
            }
        }
    }

    // MARK: - User Actions
    func togglePause(system: ActiveQuestSystem) {
        print("ActiveSystemVM: toogle pause \(system.id)")
        let newStatus: SystemAssignmentStatus =
            (system.status == .active) ? .paused : .active
        updateStatus(aqsId: system.id, status: newStatus)
    }

    func stop(system: ActiveQuestSystem) {
        print("stop \(system.id)")
        updateStatus(aqsId: system.id, status: .stopped)
    }

    // MARK: - Helpers
    private func updateStatus(aqsId: String, status: SystemAssignmentStatus) {
        print("ActiveSystemVM: updateStatus \(aqsId) \(status)")
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
