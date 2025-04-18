//
//  Quest.swift
//  SystemAdept
//
//  Created by Your Name on 2025-04-01.
//

import Foundation
import FirebaseFirestore

/// Definition of a single quest inside a QuestSystem.
struct Quest: Identifiable, Codable {
    let id: String
    let questName: String
    let questRank: Int
    let questPrompt: String
    let questAuraGranted: Double
    let questEventCount: Double
    let questEventUnits: String
    
    /// Overrides the system's default time to complete, if set.
    let timeToCompleteOverride: TimeIntervalConfig?
    
    /// Optional per‑quest cooldown (defaults to system.defaultCooldown).
    let cooldownOverride: TimeIntervalConfig?
    
    /// Overrides the system default repeat‑debuff multiplier.
    let questRepeatDebuffOverride: Double?
    
    // Firestore decoder helper (if you need custom init)
    init(from data: [String: Any], id: String) {
        self.id = id
        questName = data["questName"] as? String ?? ""
        questRank = {
            if let i = data["questRank"] as? Int { return i }
            if let s = data["questRank"] as? String, let i = Int(s) { return i }
            return 0
        }()
        questPrompt = data["questPrompt"] as? String ?? ""
        questAuraGranted = data["questAuraGranted"] as? Double ?? 0
        questEventCount = data["questEventCount"] as? Double ?? 0
        questEventUnits = data["questEventUnits"] as? String ?? ""
        
        if let dic = data["timeToCompleteOverride"] as? [String:Any],
           let amount = dic["amount"] as? Double,
           let unit = dic["unit"] as? String {
            timeToCompleteOverride = TimeIntervalConfig(amount: amount, unit: unit)
        } else {
            timeToCompleteOverride = nil
        }
        
        if let dic = data["cooldownOverride"] as? [String:Any],
           let amount = dic["amount"] as? Double,
           let unit = dic["unit"] as? String {
            cooldownOverride = TimeIntervalConfig(amount: amount, unit: unit)
        } else {
            cooldownOverride = nil
        }
        
        questRepeatDebuffOverride = data["questRepeatDebuffOverride"] as? Double
    }
}

