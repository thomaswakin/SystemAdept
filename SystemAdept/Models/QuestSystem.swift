//
//  QuestSystem.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore

/// A Quest System definition in Firestore.
struct QuestSystem: Identifiable, Codable {
  @DocumentID var id: String?          // ← this gives you a non‑optional id at runtime
  let name: String

  // your existing fields:
  let defaultTimeToComplete: TimeIntervalConfig?
  let defaultQuestCooldown: TimeIntervalConfig?
  let defaultRepeatDebuff: Double?

  // add any other metadata here…
}

struct TimeIntervalConfig: Codable {
  let amount: Double
  let unit: String    // "minutes" | "hours" | "days" | "weeks" | "months"
}
