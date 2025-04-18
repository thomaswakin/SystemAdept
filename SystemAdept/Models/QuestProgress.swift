//
//  QuestProgress.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/17/25.
//

import Foundation
import FirebaseFirestore

/// User’s progress on an individual quest.
struct QuestProgress: Identifiable, Codable {
    /// Firestore document ID
    var id: String?

    /// Reference to the global quest definition
    let questRef: DocumentReference

    /// Current status (available, locked, completed, failed)
    let status: QuestProgressStatus

    /// When it became available
    let availableAt: Date?

    /// When it expires
    let expirationTime: Date?

    /// Number of times failed/restarted
    let failedCount: Int

    // MARK: — Firestore helper

    /// Failable initializer from a Firestore document’s raw data + its documentID.
    init?(from data: [String: Any], id: String) {
        guard
            let ref = data["questRef"] as? DocumentReference,
            let statusRaw = data["status"] as? String,
            let status = QuestProgressStatus(rawValue: statusRaw)
        else {
            return nil
        }

        self.id = id
        self.questRef = ref
        self.status = status

        if let ts = data["availableAt"] as? Timestamp {
            self.availableAt = ts.dateValue()
        } else {
            self.availableAt = nil
        }

        if let ts = data["expirationTime"] as? Timestamp {
            self.expirationTime = ts.dateValue()
        } else {
            self.expirationTime = nil
        }

        self.failedCount = data["failedCount"] as? Int ?? 0
    }
}
