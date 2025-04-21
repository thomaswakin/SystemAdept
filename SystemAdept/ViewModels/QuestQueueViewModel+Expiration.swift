//
//  QuestQueueViewModel+Expiration.swift
//  SystemAdept
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension QuestQueueViewModel {
    /// Fails every QuestProgress whose expirationTime has passed.
    /// - Parameters:
    ///   - progressList: All loaded QuestProgress items
    ///   - systemId: The ActiveQuestSystem.documentID
    func expireOverdueQuests(_ progressList: [QuestProgress], systemId: String) {
        print("QuestQueueVM+Exp: expireOverdueQuests \(progressList.count)")
        let now = Date()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        for qp in progressList {
            // skip if not expired or already completed/failed
            guard
                let exp = qp.expirationTime,
                exp < now,
                qp.status != .completed,
                qp.status != .failed,
                let qpId = qp.id
            else { continue }

            // build the path to this user’s questProgress doc
            let qpRef = Firestore.firestore()
                .collection("users").document(uid)
                .collection("activeQuestSystems").document(systemId)
                .collection("questProgress").document(qpId)

            qpRef.updateData([
                "status":       QuestProgressStatus.failed.rawValue,
                "failedAt":     FieldValue.serverTimestamp(),
                "failedCount":  FieldValue.increment(Int64(1))
            ]) { error in
                if let err = error {
                    self.errorMessage = "Expire error: \(err.localizedDescription)"
                }
            }
        }
    }
}
