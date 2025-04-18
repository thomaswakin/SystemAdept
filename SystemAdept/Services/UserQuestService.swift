//
//  UserQuestService.swift
//  SystemAdept
//
//  Created by Your Name on 2025-04-18.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service for assigning systems and completing quests.
final class UserQuestService {
    static let shared = UserQuestService()
    private let db = Firestore.firestore()
    private init() {}

    /// Assigns a new quest system to the current user.
    func assignSystem(
        systemId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(
                domain: "UserQuestService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )))
            return
        }
        let aqsColl = db.collection("users").document(uid)
                         .collection("activeQuestSystems")
        let newDoc = aqsColl.document()
        let data: [String: Any] = [
            "questSystemRef": db.collection("questSystems").document(systemId),
            "assignedAt": Timestamp(date: Date()),
            "status": "active",
            "isUserSelected": true
        ]
        newDoc.setData(data) { err in
            if let err = err { completion(.failure(err)) }
            else { completion(.success(())) }
        }
    }

    /// Marks a quest completed, grants aura (with debuff), and lets you react after.
    func completeQuest(
        aqsId: String,
        progress: QuestProgress,
        quest: Quest,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let qpRef = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress").document(progress.id!)

        // Debuff-only uses per-quest override
        let failedCount = Double(progress.failedCount)
        let debuffFactor = quest.questRepeatDebuffOverride ?? 1.0
        let multiplier = pow(debuffFactor, failedCount)
        let auraGain = quest.questAuraGranted * multiplier

        let userRef = db.collection("users").document(uid)
        let batch = db.batch()

        batch.updateData([
            "status": QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ], forDocument: qpRef)
        batch.updateData([
            "aura": FieldValue.increment(auraGain)
        ], forDocument: userRef)

        batch.commit { err in
            completion?(err)
        }
    }
}

