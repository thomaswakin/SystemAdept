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
    private var activeSystemId: String?

    func start(for system: ActiveQuestSystem) {
        activeSystemId = system.id
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

                // Manual decode
                let availables: [QuestProgress] = docs.compactMap { doc -> QuestProgress? in
                    guard let raw = doc.data() as? [String:Any] else { return nil }
                    return QuestProgress(from: raw, id: doc.documentID)
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
            let quest = questDetail
        else { return }

        guard let aqsId = activeSystemId else { return }

        UserQuestService.shared.completeQuest(
            aqsId: aqsId,
            progress: qp,
            quest: quest
        ) { [weak self] err in
            if let err = err {
                self?.errorMessage = err.localizedDescription
            } else {
                // auraGain is non-optional Double
                self?.lastAuraGained = quest.questAuraGranted
            }
        }
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
                let raw = snapshot.data() as? [String:Any]
            else {
                self.errorMessage = "Failed to load quest detail."
                return
            }
            self.questDetail = Quest(from: raw, id: snapshot.documentID)
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
}
