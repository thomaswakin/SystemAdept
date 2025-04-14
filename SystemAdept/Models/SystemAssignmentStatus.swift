//
//  SystemAssignmentStatus.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore

enum SystemAssignmentStatus: String, Codable {
  case active, paused, stopped, completed, revoked
}

struct ActiveQuestSystem: Identifiable, Codable {
  @DocumentID var id: String?
  var questSystemRef: DocumentReference
  var isUserSelected: Bool
  var assignedAt: Date
  var status: SystemAssignmentStatus
  var currentQuestRef: DocumentReference?

  enum CodingKeys: String, CodingKey {
    case id
    case questSystemRef
    case isUserSelected
    case assignedAt
    case status
    case currentQuestRef
  }
}