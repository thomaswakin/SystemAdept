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

/// Combines QuestProgress with its definition and parent system.
struct ActiveQuest: Identifiable {
    let id: String              // questProgress document ID
    let aqsId: String           // activeQuestSystem ID
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
        print("MQVM: listenActiveSystems run")
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

            // Remove outdated listeners
            let currentIds = Set(docs.map { $0.documentID })
            for removed in qpListeners.keys where !currentIds.contains(removed) {
                qpListeners[removed]?.remove()
                qpListeners.removeValue(forKey: removed)
                systemQuests.removeValue(forKey: removed)
            }

            // Attach to new systems
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
        print("MWVM listenQuestProgress for \(aqsId) system \(systemName) run")
        let qpColl = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress")

        let statuses = [
            QuestProgressStatus.available.rawValue,
            QuestProgressStatus.completed.rawValue,
            QuestProgressStatus.failed.rawValue
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
                        guard let qSnap = qSnap,
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
        print("MQVM recompute active quests run")
        let now = Date()
        let all = systemQuests.values.flatMap { $0 }
        activeQuests = all.sorted {
            ($0.progress.availableAt ?? now) < ($1.progress.availableAt ?? now)
        }
    }

    /// Completes a quest, applies aura gain with debuff multiplier.
    func complete(_ aq: ActiveQuest) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("MQVM complete run")
        let qpRef = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aq.aqsId)
            .collection("questProgress").document(aq.id)
        let userRef = db.collection("users").document(uid)

        // Debuff multiplier based on failedCount
        let failed = Double(aq.progress.failedCount)
        let debuff = aq.quest.questRepeatDebuffOverride ?? 1.0
        let multiplier = pow(debuff, failed)
        let auraGain = aq.quest.questAuraGranted * multiplier

        let batch = db.batch()
        batch.updateData([
            "status": QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ], forDocument: qpRef)
        batch.updateData([
            "aura": FieldValue.increment(auraGain)
        ], forDocument: userRef)

        batch.commit { [weak self] err in
            if let err = err {
                self?.errorMessage = err.localizedDescription
            }
        }
    }

    /// Restarts an expired quest, increments failedCount, resets timer, and returns true if successful.
    func restart(_ aq: ActiveQuest, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false); return
        }
        print("MQVM restart run")
        let qpRef = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aq.aqsId)
            .collection("questProgress").document(aq.id)

        let oldAvail = aq.progress.availableAt ?? Date()
        let oldExp   = aq.progress.expirationTime ?? oldAvail
        let duration = oldExp.timeIntervalSince(oldAvail)
        let now = Date()
        let newExp = now.addingTimeInterval(duration)

        qpRef.updateData([
            "status": QuestProgressStatus.available.rawValue,
            "availableAt": Timestamp(date: now),
            "expirationTime": Timestamp(date: newExp),
            "failedCount": FieldValue.increment(Int64(1))
        ]) { err in
            completion(err == nil)
        }
    }
}
