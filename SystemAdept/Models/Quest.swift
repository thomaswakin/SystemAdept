//
//  Quest.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseFirestore

/// Represents a single quest definition in Firestore.
struct Quest: Identifiable {
    var id: String
    let questName: String
    let questRank: Int
    let questPrompt: String
    let questAuraGranted: Double
    let questEventCount: Double
    let questEventUnits: String

    /// Optional overrides
    let isRequired: Bool
    let timeToCompleteOverride: TimeIntervalConfig?
    let questCooldownOverride: TimeIntervalConfig?
    let questRepeatDebuffOverride: Double?

    /// Failable initializer from Firestore data dictionary.
    init?(from data: [String:Any], id: String) {
        self.id = id
        guard let name = data["questName"] as? String else { return nil }
        self.questName = name

        // questRank: Int, Double, or String
        if let r = data["questRank"] as? Int {
            questRank = r
        } else if let d = data["questRank"] as? Double {
            questRank = Int(d)
        } else if let s = data["questRank"] as? String, let r = Int(s) {
            questRank = r
        } else {
            questRank = 0
        }

        guard let prompt = data["questPrompt"] as? String else { return nil }
        self.questPrompt = prompt

        // questAuraGranted
        if let d = data["questAuraGranted"] as? Double {
            questAuraGranted = d
        } else if let i = data["questAuraGranted"] as? Int {
            questAuraGranted = Double(i)
        } else if let s = data["questAuraGranted"] as? String, let d = Double(s) {
            questAuraGranted = d
        } else {
            questAuraGranted = 0
        }

        // questEventCount
        if let d = data["questEventCount"] as? Double {
            questEventCount = d
        } else if let i = data["questEventCount"] as? Int {
            questEventCount = Double(i)
        } else if let s = data["questEventCount"] as? String, let d = Double(s) {
            questEventCount = d
        } else {
            questEventCount = 0
        }

        guard let units = data["questEventUnits"] as? String else { return nil }
        questEventUnits = units

        // Overrides
        isRequired = data["isRequired"] as? Bool ?? true

        if let ttc = data["timeToCompleteOverride"] as? [String:Any],
           let amt = ttc["amount"] as? Double,
           let unit = ttc["unit"] as? String {
            timeToCompleteOverride = TimeIntervalConfig(amount: amt, unit: unit)
        } else {
            timeToCompleteOverride = nil
        }

        if let cd = data["questCooldownOverride"] as? [String:Any],
           let amt = cd["amount"] as? Double,
           let unit = cd["unit"] as? String {
            questCooldownOverride = TimeIntervalConfig(amount: amt, unit: unit)
        } else {
            questCooldownOverride = nil
        }

        // The original field in Firestore is "questRepeatDebuff"
        if let d = data["questRepeatDebuff"] as? Double {
            questRepeatDebuffOverride = d
        } else if let i = data["questRepeatDebuff"] as? Int {
            questRepeatDebuffOverride = Double(i)
        } else {
            questRepeatDebuffOverride = nil
        }
    }
}
