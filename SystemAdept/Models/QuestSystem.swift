//
//  QuestSystem.swift
//  SystemAdept
//
//  Created by Your Name on 2025-04-01.
//

import Foundation

/// A group of related quests, with global settings and per‑quest overrides.
struct QuestSystem: Identifiable, Codable {
    let id: String
    let name: String
    
    /// Default time to complete each quest (unless overridden).
    let defaultTimeToComplete: TimeIntervalConfig
    
    /// Default cooldown between quests (unless overridden).
    let defaultCooldown: TimeIntervalConfig?
    
    /// Default repeat‑debuff multiplier for failed quests.
    let defaultRepeatDebuff: Double?
    
    /// All quests in this system.
    let quests: [Quest]
    
    /// Helper: group quests by their rank.
    var questsByRank: [Int: [Quest]] {
        Dictionary(grouping: quests, by: { $0.questRank })
    }
    
    // Firestore decoder helper (if using [String:Any] init)
    init(from data: [String: Any], id: String, quests: [Quest]) {
        self.id = id
        name = data["name"] as? String ?? ""
        if let dic = data["defaultTimeToComplete"] as? [String:Any],
           let amt = dic["amount"] as? Double,
           let unit = dic["unit"] as? String {
            defaultTimeToComplete = TimeIntervalConfig(amount: amt, unit: unit)
        } else {
            // fallback: zero seconds
            defaultTimeToComplete = TimeIntervalConfig(amount: 0, unit: "seconds")
        }
        if let dic = data["defaultCooldown"] as? [String:Any],
           let amt = dic["amount"] as? Double,
           let unit = dic["unit"] as? String {
            defaultCooldown = TimeIntervalConfig(amount: amt, unit: unit)
        } else {
            defaultCooldown = nil
        }
        defaultRepeatDebuff = data["defaultRepeatDebuff"] as? Double
        self.quests = quests
    }
}
