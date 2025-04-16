//
//  QuestSystem.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseFirestore

/// Represents global settings for a quest system, loaded from Firestore.
struct QuestSystem: Identifiable {
    let id: String
    let name: String
    let defaultTimeToComplete: TimeIntervalConfig
    let defaultQuestCooldown: TimeIntervalConfig
    let defaultRepeatDebuff: Double

    /// Failable initializer from a Firestore snapshot.
    init?(from snapshot: DocumentSnapshot) {
        guard
            let data = snapshot.data(),
            let name = data["name"] as? String,
            let ttcDict = data["defaultTimeToComplete"] as? [String: Any],
            let ttcAmt = ttcDict["amount"] as? Double,
            let ttcUnit = ttcDict["unit"] as? String,
            let cdDict = data["defaultQuestCooldown"] as? [String: Any],
            let cdAmt = cdDict["amount"] as? Double,
            let cdUnit = cdDict["unit"] as? String,
            let debuff = data["defaultRepeatDebuff"] as? Double
        else {
            return nil
        }

        self.id = snapshot.documentID
        self.name = name
        self.defaultTimeToComplete = TimeIntervalConfig(amount: ttcAmt, unit: ttcUnit)
        self.defaultQuestCooldown  = TimeIntervalConfig(amount: cdAmt,  unit: cdUnit)
        self.defaultRepeatDebuff   = debuff
    }
}
