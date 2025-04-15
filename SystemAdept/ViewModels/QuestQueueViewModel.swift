//
//  QuestQueueViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class QuestQueueViewModel: ObservableObject {
    // MARK: - Published
    @Published var current: QuestProgress?
    @Published var questDetail: Quest?
    @Published var countdown: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var lastAuraGained: Double?

    // MARK: - Private
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timer: Timer?
    private var activeSystem: ActiveQuestSystem?

    // MARK: - Public API

    /// Begin listening for the next available quest in the given system.
    func start(for system: ActiveQuestSystem) {
        self.activeSystem = system
        let aqsId = system.id  // non‑optional

        let qpColl = db
            .collection("users")
            .document(Auth.auth().currentUser!.uid)
            .collection("activeQuestSystems")
            .document(aqsId)
            .collection("questProgress")

        listener = qpColl
            .whereField("status", isEqualTo: QuestProgressStatus.available.rawValue)
            .order(by: "availableAt")
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    self.errorMessage = err.localizedDescription
                    return
                }

                let docs = snap?.documents ?? []
                print("🔍 QuestQueue listener fired. docs.count =", docs.count)
                for doc in docs {
                    print("   • qpId:", doc.documentID)
                }

                let now = Date()
                let availables = docs.compactMap { doc in
                    try? doc.data(as: QuestProgress.self)
                }

                if let next = availables.first(where: { ($0.availableAt ?? now) <= now }) {
                    self.current = next
                    self.fetchQuestDetail(for: next)
                    if let expiry = next.expirationTime {
                        self.startTimer(until: expiry)
                    }
                } else {
                    self.current = nil
                    self.stopTimer()
                }
            }
    }

    /// Mark the current quest completed, increment aura, and then unlock the next rank if appropriate.
    func completeCurrent() {
        guard
            let qp = current,
            let qpId = qp.id,
            let auraGain = questDetail?.questAuraGranted,
            let aqs = activeSystem
        else { return }

        let aqsId = aqs.id  // non‑optional
        let systemId = aqs.questSystemRef.documentID  // non‑optional

        let qpRef = userQuestProgressRef(aqsId: aqsId, qpId: qpId)
        let userRef = db.collection("users").document(Auth.auth().currentUser!.uid)

        let batch = db.batch()
        batch.updateData([
            "status": QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ], forDocument: qpRef)
        batch.updateData([
            "aura": FieldValue.increment(auraGain)
        ], forDocument: userRef)

        batch.commit { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                self.lastAuraGained = auraGain
                self.unlockNextRank(systemId: systemId, aqsId: aqsId)
            }
        }
    }

    /// Pause the current quest for 24 hours.
    func pauseCurrent() {
        guard
            let qp = current,
            let qpId = qp.id,
            let aqs = activeSystem
        else { return }

        let aqsId = aqs.id
        let qpRef = userQuestProgressRef(aqsId: aqsId, qpId: qpId)
        let unlockAt = Date().addingTimeInterval(24 * 3600)

        qpRef.updateData([
            "status": QuestProgressStatus.locked.rawValue,
            "availableAt": Timestamp(date: unlockAt)
        ]) { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    deinit {
        listener?.remove()
        stopTimer()
    }

    // MARK: - Private helpers

    private func fetchQuestDetail(for qp: QuestProgress) {
        qp.questRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let snapshot = snapshot else {
                self.errorMessage = "No quest data found."
                return
            }
            do {
                let quest = try snapshot.data(as: Quest.self)
                self.questDetail = quest
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func startTimer(until end: Date) {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.countdown = max(0, end.timeIntervalSinceNow)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        countdown = 0
    }

    private func userQuestProgressRef(aqsId: String, qpId: String) -> DocumentReference {
        db.collection("users")
          .document(Auth.auth().currentUser!.uid)
          .collection("activeQuestSystems")
          .document(aqsId)
          .collection("questProgress")
          .document(qpId)
    }

    /// Unlock the next rank’s quests after a completion.
    private func unlockNextRank(systemId: String, aqsId: String) {
        let systemRef = db.collection("questSystems").document(systemId)

        // 1) Fetch system defaults
        systemRef.getDocument { sysSnap, sysErr in
            if let sysErr = sysErr {
                print("Error fetching system:", sysErr)
                return
            }
            guard let sysSnap = sysSnap,
                  let system = try? sysSnap.data(as: QuestSystem.self)
            else { return }

            // 2) Fetch all questProgress docs
            let qpColl = self.db
                .collection("users")
                .document(Auth.auth().currentUser!.uid)
                .collection("activeQuestSystems")
                .document(aqsId)
                .collection("questProgress")

            qpColl.getDocuments { snap, err in
                if let err = err {
                    print("Error fetching questProgress:", err)
                    return
                }
                let docs = snap?.documents ?? []
                var byRank: [Int: [(qp: QuestProgress, quest: Quest)]] = [:]
                let group = DispatchGroup()

                for doc in docs {
                    if let qp = try? doc.data(as: QuestProgress.self),
                       let qpId = qp.id {
                        group.enter()
                        qp.questRef.getDocument { qSnap, _ in
                            defer { group.leave() }
                            if let qSnap = qSnap,
                               let quest = try? qSnap.data(as: Quest.self) {
                                byRank[quest.questRank, default: []].append((qp, quest))
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    let sortedRanks = byRank.keys.sorted()
                    for rank in sortedRanks {
                        let entries = byRank[rank]!
                        let required = entries.filter { $0.quest.isRequired }
                        let allDone = required.allSatisfy { $0.qp.status == .completed }
                        if allDone, let nextEntries = byRank[rank + 1] {
                            let batch = self.db.batch()
                            let now = Date()
                            for (qp, quest) in nextEntries where qp.status == .locked {
                                let ttc = quest.timeToCompleteOverride ?? system.defaultTimeToComplete!
                                let duration: TimeInterval
                                switch ttc.unit {
                                case "minutes": duration = ttc.amount * 60
                                case "hours":   duration = ttc.amount * 3600
                                case "days":    duration = ttc.amount * 86400
                                case "weeks":   duration = ttc.amount * 604800
                                case "months":  duration = ttc.amount * 2592000
                                default:        duration = ttc.amount
                                }
                                let qpRef = self.userQuestProgressRef(aqsId: aqsId, qpId: qp.id!)
                                batch.updateData([
                                    "status": QuestProgressStatus.available.rawValue,
                                    "availableAt": Timestamp(date: now),
                                    "expirationTime": Timestamp(date: now.addingTimeInterval(duration))
                                ], forDocument: qpRef)
                            }
                            batch.commit { batchErr in
                                if let batchErr = batchErr {
                                    print("Error unlocking next rank:", batchErr)
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
    }
}
