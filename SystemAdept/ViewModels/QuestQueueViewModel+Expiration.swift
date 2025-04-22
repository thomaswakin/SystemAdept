//
//  QuestQueueViewModel+Expiration.swift
//  SystemAdept
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

extension QuestQueueViewModel {
    /// Fails every QuestProgress whose expirationTime has passed.
    /// Queries only still-available quests that have truly expired, ensuring a single debuff each time.
    func expireOverdueQuests(_ progressList: [QuestProgress], systemId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Use a local Firestore instance
        let db = Firestore.firestore()
        let now = Date()
        let col = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(systemId)
            .collection("questProgress")

        // 1) Query all still-available quests whose expirationTime ≤ now
        col
            .whereField("status", isEqualTo: QuestProgressStatus.available.rawValue)
            .whereField("expirationTime", isLessThanOrEqualTo: Timestamp(date: now))
            .getDocuments { [weak self] snap, error in
                guard let self = self, error == nil, let docs = snap?.documents else { return }
                let batch = db.batch()

                // 2) Mark each as failed exactly once
                for doc in docs {
                    batch.updateData([
                        "status":      QuestProgressStatus.failed.rawValue,
                        "failedAt":    FieldValue.serverTimestamp(),
                    ], forDocument: doc.reference)
                }

                // 3) Commit batch
                batch.commit { err in
                    if let err = err {
                        self.errorMessage = err.localizedDescription
                    }
                }
            }
    }
}


