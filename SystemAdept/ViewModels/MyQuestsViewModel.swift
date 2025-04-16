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

/// Combines a QuestProgress with its parent system’s name and the Quest definition.
struct ActiveQuest: Identifiable {
    let id: String              // questProgress document ID
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

    /// Holds the latest list of quests for each active system.
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

            // Remove listeners for systems that are no longer active
            let currentIds = Set(docs.map { $0.documentID })
            for removedId in qpListeners.keys where !currentIds.contains(removedId) {
                qpListeners[removedId]?.remove()
                qpListeners.removeValue(forKey: removedId)
                self.systemQuests.removeValue(forKey: removedId)
            }

            // Add listeners for any newly active systems
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

            // After adjusting listeners, recompute the flat list
            self.recomputeActiveQuests()
        }
    }

    private func listenQuestProgress(for aqsId: String, systemName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let qpColl = db
            .collection("users").document(uid)
            .collection("activeQuestSystems")
            .document(aqsId)
            .collection("questProgress")

        let listener = qpColl
            .whereField("status", isEqualTo: QuestProgressStatus.available.rawValue)
            .order(by: "availableAt")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    self.errorMessage = err.localizedDescription
                    return
                }
                let docs = snap?.documents ?? []
                var newList: [ActiveQuest] = []
                let group = DispatchGroup()

                for doc in docs {
                    // Decode QuestProgress
                    guard let qp = try? doc.data(as: QuestProgress.self),
                          let qpId = qp.id else { continue }

                    group.enter()
                    qp.questRef.getDocument { qSnap, _ in
                        defer { group.leave() }
                        guard
                            let qSnap = qSnap,
                            let qData = qSnap.data(),
                            let quest = Quest(from: qData, id: qSnap.documentID)
                        else {
                            return
                        }
                        let aq = ActiveQuest(
                            id: qpId,
                            systemName: systemName,
                            progress: qp,
                            quest: quest
                        )
                        newList.append(aq)
                    }
                }

                group.notify(queue: .main) {
                    // Store this system's quests, then recompute the aggregate
                    self.systemQuests[aqsId] = newList
                    self.recomputeActiveQuests()
                }
            }

        qpListeners[aqsId] = listener
    }

    /// Flattens `systemQuests` into `activeQuests`, sorted by availableAt.
    private func recomputeActiveQuests() {
        let now = Date()
        let all = systemQuests.values.flatMap { $0 }
        self.activeQuests = all.sorted {
            ($0.progress.availableAt ?? now) < ($1.progress.availableAt ?? now)
        }
    }
}
