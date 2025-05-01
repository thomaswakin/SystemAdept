//
//  TimeIntervalConfig.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/15/25.
//


import Foundation

/// Reusable configuration for time intervals (amount + unit).
struct TimeIntervalConfig: Codable {
    let amount: Double
    let unit: String
}
