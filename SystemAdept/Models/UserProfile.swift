//
//  UserProfile.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//

import Foundation

// MARK: - User Profile Model

struct UserProfile: Codable, Identifiable {
    var id: String
    var email: String
    var name: String
    var aura: Int
    var skillPoints: String
    var strength: StrengthMetrics
    var agility: AgilityMetrics
    var stamina: Int
    var power: Int
    var focus: Int
    var discipline: Int
    var initiative: Int

    // ─── Newly added ────────────────────────────
    /// Hour in 24‑hour time (0–23)
    var restStartHour: Int = 22
    var restStartMinute: Int = 0
    var restEndHour: Int = 6
    var restEndMinute: Int = 0
    // ─────────────────────────────────────────────

    // ... your existing init/from–dictionary code ...
}

struct StrengthMetrics: Codable {
    var upperBody: Int
    var core: Int
    var lowerBody: Int
}

struct AgilityMetrics: Codable {
    var flexibility: Int
    var speed: Int
    var balance: Int
}
