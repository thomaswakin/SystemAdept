//
//  MyQuestsViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/15/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ActiveQuest: Identifiable {
    let id: String         // questProgress doc ID
    let aqsId: String      // activeQuestSystem ID
    let systemName: String
    let progress: QuestProgress
    let quest: Quest
}

final class MyQuestsViewModel: ObservableObject {
    @Published var activeQuests: [ActiveQuest] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var aqsListener: ListenerRegistration?
    private var qpListeners: [String: ListenerRegistration] = [:]
    private var systemQuests: [String: [ActiveQuest]] = [:]

    init() {
        listenActiveSystems()
    }

    deinit {
        aqsListener?.remove()
        qpListeners.values.forEach { $0.remove() }
    }

    private func listenActiveSystems() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let aqsColl = db
            .collection("users").document(uid)
            .collection("activeQuestSystems")

        aqsListener = aqsColl.addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                self.errorMessage = err.localizedDescription
                return
            }
            let docs = snap?.documents ?? []

            // Clean up listeners & caches for removed systems
            let currentIds = Set(docs.map { $0.documentID })
            for removed in qpListeners.keys where !currentIds.contains(removed) {
                qpListeners[removed]?.remove()
                qpListeners.removeValue(forKey: removed)
                systemQuests.removeValue(forKey: removed)
            }

            // Add listeners for newly active systems
            for doc in docs {
                let aqsId = doc.documentID
                if qpListeners[aqsId] == nil {
                    let data = doc.data()
                    let systemName = data["questSystemName"] as? String
                        ?? (data["questSystemRef"] as? DocumentReference)?.documentID
                        ?? "Unknown"
                    listenQuestProgress(for: aqsId, systemName: systemName)
                }
            }
            recomputeActiveQuests()
        }
    }

    private func listenQuestProgress(for aqsId: String, systemName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let qpColl = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress")

        // Listen to both available and completed statuses
        let statuses = [
            QuestProgressStatus.available.rawValue,
            QuestProgressStatus.completed.rawValue
        ]

        let listener = qpColl
            .whereField("status", in: statuses)
            .order(by: "availableAt")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    self.errorMessage = err.localizedDescription
                    return
                }
                let docs = snap?.documents ?? []
                var list: [ActiveQuest] = []
                let group = DispatchGroup()

                for doc in docs {
                    guard let qp = try? doc.data(as: QuestProgress.self),
                          let qpId = qp.id else { continue }
                    group.enter()
                    qp.questRef.getDocument { qSnap, _ in
                        defer { group.leave() }
                        guard
                            let qSnap = qSnap,
                            let qData = qSnap.data(),
                            let quest = Quest(from: qData, id: qSnap.documentID)
                        else { return }
                        list.append(ActiveQuest(
                            id: qpId,
                            aqsId: aqsId,
                            systemName: systemName,
                            progress: qp,
                            quest: quest
                        ))
                    }
                }

                group.notify(queue: .main) {
                    self.systemQuests[aqsId] = list
                    self.recomputeActiveQuests()
                }
            }

        qpListeners[aqsId] = listener
    }

    private func recomputeActiveQuests() {
        let now = Date()
        // Flatten all systems’ quests
        let all = systemQuests.values.flatMap { $0 }
        // Sort by soonest availableAt (for consistency; view will filter further)
        activeQuests = all.sorted {
            ($0.progress.availableAt ?? now) < ($1.progress.availableAt ?? now)
        }
    }

    /// Marks an available quest as completed.
    func complete(_ aq: ActiveQuest) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let qpRef = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aq.aqsId)
            .collection("questProgress").document(aq.id)

        qpRef.updateData([
            "status": QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ]) { [weak self] err in
            if let err = err {
                self?.errorMessage = err.localizedDescription
            }
        }
    }
}
