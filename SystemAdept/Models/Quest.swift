//
//  Quest.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseFirestore   // for @DocumentID

struct Quest: Identifiable, Codable {
    @DocumentID var id: String?
    let questName: String
    let questRank: Int
    let questPrompt: String
    let questAuraGranted: Double
    let questEventCount: Double
    let questEventUnits: String
    let isRequired: Bool
    let timeToCompleteOverride: TimeIntervalConfig?
    let questCooldownOverride: TimeIntervalConfig?
    let questRepeatDebuffOverride: Double?
}