//
//  QuestProgressStatus.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore

enum QuestProgressStatus: String, Codable {
  case locked, available, inProgress = "in_progress", completed, failed
}

struct QuestProgress: Identifiable, Codable {
  @DocumentID var id: String?
  var questRef: DocumentReference
  var status: QuestProgressStatus
  var availableAt: Date?
  var startTime: Date?
  var expirationTime: Date?
  var completedAt: Date?
  var failedCount: Int
}
