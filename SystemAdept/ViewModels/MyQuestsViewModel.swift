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
    // MARK: Published
    @Published var activeQuests: [ActiveQuest] = []
    @Published var errorMessage: String?

    // MARK: Private
    private let db = Firestore.firestore()
    private var aqsListener: ListenerRegistration?
    private var qpListeners: [String: ListenerRegistration] = [:]
    private var systemQuests: [String: [ActiveQuest]] = [:]

    // *** New: keep decoded ActiveQuestSystems and timer ***
    private var activeQuestSystems: [ActiveQuestSystem] = []
    private var maintenanceTimer: Timer?

    // MARK: Init / Deinit
    init() {
        listenActiveSystems()
        startMaintenanceTimer()
    }

    deinit {
        aqsListener?.remove()
        qpListeners.values.forEach { $0.remove() }
        maintenanceTimer?.invalidate()
    }

    // MARK: - Listen Active Systems
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

            // 1) Decode and store ActiveQuestSystem models manually
            self.activeQuestSystems = docs.compactMap { doc in
                let data = doc.data()
                // Required Firestore reference to the QuestSystem
                guard let questSystemRef = data["questSystemRef"] as? DocumentReference else {
                    return nil
                }
                // Optional system name override
                let systemName = data["questSystemName"] as? String
                    ?? questSystemRef.documentID
                // Optional user‑selected flag
                let isUserSelected = data["isUserSelected"] as? Bool ?? false
                // Assigned timestamp
                let assignedAt: Date = {
                    if let ts = data["assignedAt"] as? Timestamp {
                        return ts.dateValue()
                    }
                    return Date()
                }()
                // Status enum
                let status: SystemAssignmentStatus = {
                    let raw = data["status"] as? String ?? SystemAssignmentStatus.active.rawValue
                    return SystemAssignmentStatus(rawValue: raw) ?? .active
                }()
                // Optional current quest pointer
                let currentQuestRef = data["currentQuestRef"] as? DocumentReference

                return ActiveQuestSystem(
                    id: doc.documentID,
                    questSystemRef: questSystemRef,
                    questSystemName: systemName,
                    isUserSelected: isUserSelected,
                    assignedAt: assignedAt,
                    status: status,
                    currentQuestRef: currentQuestRef
                )
            }

            // 2) Remove outdated listeners
            let currentIds = Set(docs.map { $0.documentID })
            for removed in qpListeners.keys where !currentIds.contains(removed) {
                qpListeners[removed]?.remove()
                qpListeners.removeValue(forKey: removed)
                systemQuests.removeValue(forKey: removed)
            }

            // 3) Attach listeners for new systems
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

            // 4) Recompute UI list
            self.recomputeActiveQuests()

            // 5) Run maintenance immediately for each system
            self.activeQuestSystems.forEach {
                QuestQueueViewModel.runMaintenance(for: $0)
            }
        }
    }

    // MARK: - QuestProgress Listeners
    private func listenQuestProgress(for aqsId: String, systemName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("MQVM listenQuestProgress for \(aqsId) system \(systemName) run")
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

    // MARK: - Recompute UI State
    private func recomputeActiveQuests() {
        print("MQVM recompute active quests run")
        let now = Date()
        let all = systemQuests.values.flatMap { $0 }
        activeQuests = all.sorted {
            ($0.progress.availableAt ?? now) < ($1.progress.availableAt ?? now)
        }
    }

    // MARK: - Maintenance Timer
    private func startMaintenanceTimer() {
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Run the same maintenance for each active system
            self.activeQuestSystems.forEach {
                QuestQueueViewModel.runMaintenance(for: $0)
            }
        }
    }

    // MARK: - User Actions

    /// Delegates to QuestQueueViewModel.complete(_:)
    func complete(_ aq: ActiveQuest) {
        guard let system = activeQuestSystems.first(where: { $0.id == aq.aqsId }) else { return }
        QuestQueueViewModel.complete(aq, in: system)
    }

    /// Delegates to QuestQueueViewModel.restart(_:)
    func restart(_ aq: ActiveQuest, completion: @escaping (Bool) -> Void) {
        guard let system = activeQuestSystems.first(where: { $0.id == aq.aqsId }) else {
            completion(false); return
        }
        QuestQueueViewModel.restart(aq, in: system)
        completion(true)
    }
}
