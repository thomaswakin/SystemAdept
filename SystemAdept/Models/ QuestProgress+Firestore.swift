//
//  QuestProgress+Firestore.swift
//  SystemAdept
//

import Foundation
import FirebaseFirestore

extension QuestProgress {
    /// Parses a QuestProgress from a Firestore DocumentSnapshot.
    ///
    /// - Parameter snapshot: The Firestore document snapshot to parse.
    /// - Returns: A fully populated QuestProgress.
    /// - Throws: NSError if any required fields are missing or invalid.
    static func fromSnapshot(_ snapshot: DocumentSnapshot) throws -> QuestProgress {
        let data = snapshot.data() ?? [:]
        let docID = snapshot.documentID
        
        // Required fields
        guard let questRef = data["questRef"] as? DocumentReference else {
            throw NSError(
                domain: "QuestProgressParsing",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing or invalid 'questRef' field"]
            )
        }
        guard let statusRaw = data["status"] as? String,
              let status = QuestProgressStatus(rawValue: statusRaw) else {
            throw NSError(
                domain: "QuestProgressParsing",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing or invalid 'status' field"]
            )
        }
        
        // Optional timestamp fields
        let availableAt   = (data["availableAt"]   as? Timestamp)?.dateValue()
        let startTime     = (data["startTime"]     as? Timestamp)?.dateValue()
        let expirationTime = (data["expirationTime"] as? Timestamp)?.dateValue()
        let completedAt   = (data["completedAt"]   as? Timestamp)?.dateValue()
        
        // Optional Int field
        let failedCount   = data["failedCount"] as? Int ?? 0
        
        // Construct the model
        return QuestProgress(
            id:            docID,
            questRef:      questRef,
            status:        status,
            availableAt:   availableAt,
            startTime:     startTime,
            expirationTime: expirationTime,
            completedAt:   completedAt,
            failedCount:   failedCount
        )
    }
}
