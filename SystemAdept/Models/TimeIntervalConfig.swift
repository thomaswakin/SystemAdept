//
//  TimeIntervalConfig.swift
//  SystemAdept
//
//  Created by Your Name on 2025-04-18.
//

import Foundation

/// Reusable configuration for time intervals (amount + unit).
/// e.g. 0.25 days, 10 hours, 30 minutes, etc.
struct TimeIntervalConfig: Codable {
    let amount: Double
    let unit: String
    
    /// Converts `amount`+`unit` into seconds.
    /// Supported units: seconds, minutes, hours, days, weeks, months
    var seconds: TimeInterval {
        switch unit.lowercased() {
        case "second", "seconds":
            return amount
        case "minute", "minutes":
            return amount * 60
        case "hour", "hours":
            return amount * 60 * 60
        case "day", "days":
            return amount * 60 * 60 * 24
        case "week", "weeks":
            return amount * 60 * 60 * 24 * 7
        case "month", "months":
            // approximate a month as 30 days
            return amount * 60 * 60 * 24 * 30
        default:
            // fallback: treat as seconds
            return amount
        }
    }
}
