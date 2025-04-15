//
//  SystemAssignmentStatus.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


//import Foundation
//import FirebaseFirestore

//enum SystemAssignmentStatus: String, Codable {
//  case active, paused, stopped, completed, revoked
//}

//struct ActiveQuestSystem: Identifiable, Codable {
//  @DocumentID var id: String?
//  var questSystemRef: DocumentReference
//  var isUserSelected: Bool
//  var assignedAt: Date
//  var status: SystemAssignmentStatus
//  var currentQuestRef: DocumentReference?
//
//  enum CodingKeys: String, CodingKey {
//    case id
//    case questSystemRef
//    case isUserSelected
//    case assignedAt
//    case status
//    case currentQuestRef
//  }
//}

import Foundation
import FirebaseFirestore

enum SystemAssignmentStatus: String, Decodable {
  case active, paused, stopped, completed, revoked
}

struct ActiveQuestSystem: Identifiable, Decodable, Hashable {
  @DocumentID var id: String?
  let questSystemRef: DocumentReference
  let questSystemName: String
  let isUserSelected: Bool
  let assignedAt: Date
  let status: SystemAssignmentStatus
  let currentQuestRef: DocumentReference?

  enum CodingKeys: String, CodingKey {
    case id, questSystemRef, questSystemName, isUserSelected, assignedAt, status, currentQuestRef
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.id                = try c.decodeIfPresent(String.self, forKey: .id)
    self.questSystemRef    = try c.decode(DocumentReference.self, forKey: .questSystemRef)
    self.questSystemName   = try c.decode(String.self, forKey: .questSystemName)

    if let boolVal = try? c.decode(Bool.self, forKey: .isUserSelected) {
      self.isUserSelected = boolVal
    } else if let intVal = try? c.decode(Int.self, forKey: .isUserSelected) {
      self.isUserSelected = (intVal != 0)
    } else {
      self.isUserSelected = false
    }

    let ts = try c.decode(Timestamp.self, forKey: .assignedAt)
    self.assignedAt = ts.dateValue()
    self.status = try c.decode(SystemAssignmentStatus.self, forKey: .status)
    self.currentQuestRef = try c.decodeIfPresent(DocumentReference.self,
                                                 forKey: .currentQuestRef)
  }

  // Hashable conformance
  static func == (lhs: ActiveQuestSystem, rhs: ActiveQuestSystem) -> Bool {
    return lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
