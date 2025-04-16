//
//  MyQuestsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/15/25.
//

import SwiftUI

struct MyQuestsView: View {
    @StateObject private var vm = MyQuestsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            errorBanner

            if vm.activeQuests.isEmpty {
                noQuestsView
            } else {
                questsScrollView
            }
        }
        .navigationTitle("Active Quests")
    }

    // MARK: - Subviews

    private var errorBanner: some View {
        Group {
            if let err = vm.errorMessage {
                Text("Error: \(err)")
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
            }
        }
    }

    private var noQuestsView: some View {
        VStack {
            Spacer()
            Text("No active quests.")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var questsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.activeQuests) { aq in
                    questRow(for: aq)
                }
            }
            .padding()
        }
    }

    private func questRow(for aq: ActiveQuest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(aq.systemName)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(aq.quest.questName)
                .font(.headline)
            HStack {
                Text(aq.progress.status.rawValue.capitalized) // <-- use rawValue here
                Spacer()
                if let expiration = aq.progress.expirationTime {
                    let remaining = Int(expiration.timeIntervalSince(Date()))
                    Text(remaining > 0
                         ? "Expires in \(remaining)s"
                         : "Expired")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct MyQuestsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MyQuestsView()
        }
    }
}
