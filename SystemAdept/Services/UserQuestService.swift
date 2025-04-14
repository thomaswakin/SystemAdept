//
//  UserQuestService.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

final class UserQuestService {
  private let db = Firestore.firestore()
  private var uid: String {
    Auth.auth().currentUser!.uid
  }

  /// Assigns a QuestSystem to the current user.
  func assignSystem(systemId: String, isUserSelected: Bool = true,
                    completion: @escaping (Result<ActiveQuestSystem, Error>) -> Void) {
    let aqsRef = db
      .collection("users")
      .document(uid)
      .collection("activeQuestSystems")
      .document() // auto‑ID

    let data: [String: Any] = [
      "questSystemRef": db.collection("questSystems").document(systemId),
      "isUserSelected": isUserSelected,
      "assignedAt": Timestamp(date: Date()),
      "status": SystemAssignmentStatus.active.rawValue
    ]

    aqsRef.setData(data) { error in
      if let error = error {
        completion(.failure(error))
      } else {
        aqsRef.getDocument { snap, err in
          if let err = err {
            completion(.failure(err))
          } else if let snap = snap, snap.exists {
            do {
              let system = try snap.data(as: ActiveQuestSystem.self)
              completion(.success(system))
            } catch {
              completion(.failure(error))
            }
          }
        }
      }
    }
  }
}

extension UserQuestService {
  /// Update the status of an assigned QuestSystem.
  func updateSystemStatus(aqsId: String,
                          status: SystemAssignmentStatus,
                          completion: ((Error?) -> Void)? = nil) {
    let aqsRef = db
      .collection("users")
      .document(uid)
      .collection("activeQuestSystems")
      .document(aqsId)
    aqsRef.updateData([
      "status": status.rawValue
    ]) { error in
      completion?(error)
    }
  }
}
