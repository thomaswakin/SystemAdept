//
//  for.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/23/25.
//


import Foundation

/// Shared filter enum for MyQuestsView and ViewModel
enum QuestFilter: String, CaseIterable, Identifiable {
    case all      = "All"
    case today    = "Today"
    case complete = "Complete"

    var id: String { rawValue }

    /// Does this filter include the given date?
    func matches(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        let now = Date()
        switch self {
        case .all:
            return true
        case .today:
            return Calendar.current.isDate(date, inSameDayAs: now)
        case .complete:
            return true
        }
    }
}