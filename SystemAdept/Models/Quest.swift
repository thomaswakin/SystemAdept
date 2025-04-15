//
//  Quest.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


//import Foundation
//import FirebaseFirestore   // for @DocumentID
//
//struct Quest: Identifiable, Codable {
//    @DocumentID var id: String?
//    let questName: String
//    let questRank: Int
//    let questPrompt: String
//    let questAuraGranted: Double
//    let questEventCount: Double
//    let questEventUnits: String
//    let isRequired: Bool
//    let timeToCompleteOverride: TimeIntervalConfig?
//    let questCooldownOverride: TimeIntervalConfig?
//    let questRepeatDebuffOverride: Double?
//}

import Foundation
import FirebaseFirestore

/// Represents a single quest definition in Firestore.
struct Quest: Identifiable, Decodable {
    @DocumentID var id: String?
    let questName: String
    let questRank: Int
    let questPrompt: String
    let questAuraGranted: Double
    let questEventCount: Double
    let questEventUnits: String

    /// Optional fields; if missing, we provide sensible defaults.
    let isRequired: Bool
    let timeToCompleteOverride: TimeIntervalConfig?
    let questCooldownOverride: TimeIntervalConfig?
    let questRepeatDebuffOverride: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case questName
        case questRank
        case questPrompt
        case questAuraGranted
        case questEventCount
        case questEventUnits
        case isRequired
        case timeToCompleteOverride
        case questCooldownOverride
        // Map the old field name to our new property
        case questRepeatDebuffOverride = "questRepeatDebuff"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id   = try c.decodeIfPresent(String.self, forKey: .id)
        self.questName            = try c.decode(String.self, forKey: .questName)
        self.questRank            = try c.decode(Int.self, forKey: .questRank)
        self.questPrompt          = try c.decode(String.self, forKey: .questPrompt)
        self.questAuraGranted     = try c.decode(Double.self, forKey: .questAuraGranted)
        self.questEventCount      = try c.decode(Double.self, forKey: .questEventCount)
        self.questEventUnits      = try c.decode(String.self, forKey: .questEventUnits)
        // Default to true if the field is missing
        self.isRequired           = try c.decodeIfPresent(Bool.self, forKey: .isRequired) ?? true
        self.timeToCompleteOverride = try c.decodeIfPresent(TimeIntervalConfig.self,
                                                           forKey: .timeToCompleteOverride)
        self.questCooldownOverride  = try c.decodeIfPresent(TimeIntervalConfig.self,
                                                           forKey: .questCooldownOverride)
        // The CSV used to have "questRepeatDebuff", so we map it here
        self.questRepeatDebuffOverride = try c.decodeIfPresent(Double.self,
                                                               forKey: .questRepeatDebuffOverride)
    }
}
