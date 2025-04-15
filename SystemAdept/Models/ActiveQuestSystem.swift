//
//  SystemAssignmentStatus.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseFirestore

enum SystemAssignmentStatus: String {
  case active, paused, stopped, completed, revoked
}

struct ActiveQuestSystem: Identifiable, Hashable {
  let id: String
  let questSystemRef: DocumentReference
  let questSystemName: String
  let isUserSelected: Bool
  let assignedAt: Date
  let status: SystemAssignmentStatus
  let currentQuestRef: DocumentReference?

  // Hashable conformance
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  static func ==(lhs: ActiveQuestSystem, rhs: ActiveQuestSystem) -> Bool {
    return lhs.id == rhs.id
  }
}
