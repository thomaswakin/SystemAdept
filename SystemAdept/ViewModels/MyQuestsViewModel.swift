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
    @Published var didLoadInitial: Bool = false
    private var hasLoadedInitial: Bool = false
    @Published var errorMessage: String?

    // MARK: Private
    private let db = Firestore.firestore()
    private var aqsListener: ListenerRegistration?
    private var qpListeners: [String: ListenerRegistration] = [:]
    private var systemQuests: [String: [ActiveQuest]] = [:]

    // Hold decoded systems + a timer for maintenance
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
        print("MyQuestsVM: listenActiveSystems")
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

            // Decode ActiveQuestSystem
            self.activeQuestSystems = docs.compactMap { doc in
                let data = doc.data()
                guard let questSystemRef = data["questSystemRef"] as? DocumentReference else {
                    return nil
                }
                let systemName = data["questSystemName"] as? String
                    ?? questSystemRef.documentID
                let isUserSelected = data["isUserSelected"] as? Bool ?? false
                let assignedAt: Date = (data["assignedAt"] as? Timestamp)?.dateValue() ?? Date()
                let rawStatus = data["status"] as? String
                                ?? SystemAssignmentStatus.active.rawValue
                let status = SystemAssignmentStatus(rawValue: rawStatus) ?? .active
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

            // Remove outdated questProgress listeners
            let currentIds = Set(docs.map { $0.documentID })
            for removed in qpListeners.keys where !currentIds.contains(removed) {
                qpListeners[removed]?.remove()
                qpListeners.removeValue(forKey: removed)
                systemQuests.removeValue(forKey: removed)
            }

            // Attach listeners for each new system
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

            // ─── **No longer** recompute here ───
            // self.recomputeActiveQuests()

            // Run maintenance immediately for each system
            self.activeQuestSystems.forEach {
                QuestQueueViewModel.runMaintenance(for: $0)
            }
        }
    }

    // MARK: - QuestProgress Listeners
    private func listenQuestProgress(for aqsId: String, systemName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("MyQuestsVM: listenQuestProgress for \(aqsId) system \(systemName)")
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
                    // Recompute **after** we have real questProgress data
                    self.recomputeActiveQuests()
                }
            }

        qpListeners[aqsId] = listener
    }

    // MARK: - Recompute UI State
    private func recomputeActiveQuests() {
        print("MyQuestsVM: recompute active quests run")
        let now = Date()
        let all = systemQuests.values.flatMap { $0 }

        // Flip didLoadInitial only on the first *real* recompute
        if !hasLoadedInitial {
            didLoadInitial  = true
            hasLoadedInitial = true
        }

        // Sort with a single‐expression closure
        activeQuests = all.sorted { a, b in
            (a.progress.availableAt ?? now) < (b.progress.availableAt ?? now)
        }
    }

    // MARK: - Maintenance Timer
    private func startMaintenanceTimer() {
        print("MyQuestsVM: startMaintenanceTimer run")
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.activeQuestSystems.forEach {
                QuestQueueViewModel.runMaintenance(for: $0)
            }
        }
    }

    // MARK: - User Actions
    func complete(_ aq: ActiveQuest) {
        print("MyQuestsVM: complete \(aq)")
        guard let system = activeQuestSystems.first(where: { $0.id == aq.aqsId }) else { return }
        QuestQueueViewModel.complete(aq, in: system)
        recomputeActiveQuests()
    }

    func restart(_ aq: ActiveQuest, completion: @escaping (Bool) -> Void) {
        print("MyQuestsVM: restart \(aq)")
        guard let system = activeQuestSystems.first(where: { $0.id == aq.aqsId }) else {
            completion(false); return
        }
        QuestQueueViewModel.restart(aq, in: system)
        completion(true)
        recomputeActiveQuests()
    }

    // MARK: - Filter & Sort
    func filteredAndSorted(
        filter: QuestFilter,
        ascending: Bool
    ) -> [ActiveQuest] {
        let all = activeQuests

        // 1) filter
        let filtered: [ActiveQuest]
        switch filter {
        case .today:
            filtered = all.filter { quest in
                let s = quest.progress.status
                return (s == .available || s == .failed)
                    && filter.matches(quest.progress.expirationTime)
            }

        case .all:
            filtered = all.filter {
                $0.progress.status == .available
                || $0.progress.status == .failed
            }

        case .complete:
            filtered = all.filter {
                $0.progress.status == .completed
            }
        }

        // 2) sort
        return filtered.sorted { a, b in
            let d1 = (filter == .complete
                      ? (a.progress.completedAt ?? .distantPast)
                      : (a.progress.expirationTime ?? .distantPast))
            let d2 = (filter == .complete
                      ? (b.progress.completedAt ?? .distantPast)
                      : (b.progress.expirationTime ?? .distantPast))
            return ascending ? (d1 < d2) : (d1 > d2)
        }
    }
}
