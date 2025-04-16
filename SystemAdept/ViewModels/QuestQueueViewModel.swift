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
    @Published var current: QuestProgress?
    @Published var questDetail: Quest?
    @Published var countdown: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var lastAuraGained: Double?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timer: Timer?
    private var activeSystem: ActiveQuestSystem?

    func start(for system: ActiveQuestSystem) {
        self.activeSystem = system
        let qpColl = db
            .collection("users")
            .document(Auth.auth().currentUser!.uid)
            .collection("activeQuestSystems")
            .document(system.id)
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
                let now = Date()

                // Debug
                print("🔍 QuestQueue listener fired. docs.count =", docs.count)

                // Map to QuestProgress
                let availables = docs.compactMap { doc -> QuestProgress? in
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

    func completeCurrent() {
        guard
            let qp = current,
            let qpId = qp.id,
            let auraGain = questDetail?.questAuraGranted,
            let aqs = activeSystem
        else { return }

        let aqsId = aqs.id
        let systemId = aqs.questSystemRef.documentID
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

    private func fetchQuestDetail(for qp: QuestProgress) {
        qp.questRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard
                let snapshot = snapshot,
                let data = snapshot.data(),
                let quest = Quest(from: data, id: snapshot.documentID)
            else {
                self.errorMessage = "Failed to load quest detail."
                return
            }
            self.questDetail = quest
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

    private func unlockNextRank(systemId: String, aqsId: String) {
        let systemRef = db.collection("questSystems").document(systemId)

        systemRef.getDocument { [weak self] sysSnap, sysErr in
            guard let self = self else { return }
            if let sysErr = sysErr {
                print("Error fetching system:", sysErr)
                return
            }
            guard
                let snap = sysSnap,
                let questSystem = QuestSystem(from: snap)
            else {
                print("Malformed QuestSystem data")
                return
            }

            // Fetch all questProgress docs
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
                            if
                                let qSnap = qSnap,
                                let data = qSnap.data(),
                                let quest = Quest(from: data, id: qSnap.documentID)
                            {
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
                                // Use questSystem.defaultTimeToComplete here
                                let ttcCfg = quest.timeToCompleteOverride
                                              ?? questSystem.defaultTimeToComplete
                                let duration: TimeInterval
                                switch ttcCfg.unit {
                                case "minutes": duration = ttcCfg.amount * 60
                                case "hours":   duration = ttcCfg.amount * 3600
                                case "days":    duration = ttcCfg.amount * 86400
                                case "weeks":   duration = ttcCfg.amount * 604800
                                case "months":  duration = ttcCfg.amount * 2592000
                                default:        duration = ttcCfg.amount
                                }
                                let qpRef = self.userQuestProgressRef(aqsId: aqsId,
                                                                      qpId: qp.id!)
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
