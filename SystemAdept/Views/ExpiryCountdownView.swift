//
//  ExpiryCountdownView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/23/25.
//


import SwiftUI

// MARK: - Live Expiry Countdown

/// Formats a human‑readable remaining time
fileprivate func timeRemainingText(until expiry: Date) -> String {
    let interval = expiry.timeIntervalSinceNow
    guard interval > 0 else { return "Expired" }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.year, .month, .day, .hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    formatter.zeroFormattingBehavior = .dropAll

    return formatter.string(from: interval) ?? ""
}

/// A self‑contained view that shows a live countdown from `now` between `start`→`expiry`.
struct ExpiryCountdownView: View {
    let start:  Date
    let expiry: Date
    let now:    Date

    // Total window for this quest
    private var total: TimeInterval { expiry.timeIntervalSince(start) }
    // Remaining time clamped ≥ 0
    private var remaining: TimeInterval { max(0, expiry.timeIntervalSince(now)) }
    // Human‑readable remaining string
    private var label:     String { timeRemainingText(until: expiry) }

    /// Color logic: gray if expired, red if ≤10% left, orange if <1h, else green
    private var color: Color {
        if remaining <= 0 {
            return .gray
        } else if remaining < total * 0.1 {
            return .red
        } else if remaining < 3600 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        Text("Expires in \(label)")
            .font(.caption2)
            .monospacedDigit()
            .foregroundColor(color)
    }
}
