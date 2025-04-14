//
//  UserProfile.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//


import Foundation

// MARK: - User Profile Model

struct UserProfile: Codable, Identifiable {
    // The document ID will be the user's UID.
    var id: String
    // Login email address (read-only)
    let email: String
    // Editable user name (defaults to first part of email)
    var name: String
    // Read-only values
    let aura: Int        // Default: 0
    let skillPoints: String  // Default: "--"
    
    // Metrics
    var strength: StrengthMetrics
    var agility: AgilityMetrics
    var stamina: Int
    var power: Int
    var focus: Int
    var discipline: Int
    var initiative: Int
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