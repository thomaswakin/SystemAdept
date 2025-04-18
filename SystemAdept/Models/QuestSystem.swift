//
//  QuestSystem.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation

/// Definition of a single quest system, containing its global settings
/// and the list of all quests (across ranks).
struct QuestSystem: Identifiable {
    let id: String
    let name: String
    
    /// Default time (in seconds) a quest in this system should take,
    /// unless overridden by the quest itself.
    let defaultTimeToComplete: TimeInterval
    
    /// Default cooldown (in seconds) between quests in this system,
    /// unless overridden per‐quest.
    let defaultCooldown: TimeInterval
    
    /// Default repeat‐debuff multiplier to apply on failed counts
    /// (e.g. 0.5 means each failure halves the reward).
    let defaultRepeatDebuff: Double?
    
    /// All quests across every rank in this system.
    let quests: [Quest]
    
    // MARK: - Computed Helpers
    
    /// Groups `quests` by their integer `questRank` into a dictionary.
    /// e.g. all quests where quest.questRank == 1 will be in `.questsByRank[1]`.
    var questsByRank: [Int: [Quest]] {
        Dictionary(grouping: quests, by: { $0.questRank })
    }
}
