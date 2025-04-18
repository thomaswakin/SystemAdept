//
//  ProfileView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let user = authVM.userProfile {
                VStack(spacing: 24) {
                    // MARK: Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.largeTitle)
                            .bold()
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // MARK: Aura (full‑width)
                    StatCard(title: "Aura", value: display(user.aura))
                        .padding(.horizontal)
                    
                    // MARK: Rest Cycle Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rest Cycle")
                            .font(.headline)
                        Text(String(format: "%02d:%02d – %02d:%02d",
                                    user.restStartHour, user.restStartMinute,
                                    user.restEndHour,   user.restEndMinute))
                        NavigationLink("Edit Rest Cycle") {
                            RestCycleSettingsView()
                        }
                    }
                    .padding(.horizontal)

//                    // MARK: Skill Points Section
//                    VStack(alignment: .leading, spacing: 16) {
//                        Text("Skill Points")
//                            .font(.title2)
//                            .bold()
//                            .padding(.horizontal)
//
//                        // Agility
//                        Text("Agility")
//                            .font(.headline)
//                            .padding(.horizontal)
//                        StatsList(items: [
//                            ("Speed", display(user.agility.speed)),
//                            ("Balance", display(user.agility.balance)),
//                            ("Flexibility", display(user.agility.flexibility))
//                        ], indent: 24)
//
//                        // Strength
//                        Text("Strength")
//                            .font(.headline)
//                            .padding(.horizontal)
//                        StatsList(items: [
//                            ("Core", display(user.strength.core)),
//                            ("Lower Body", display(user.strength.lowerBody)),
//                            ("Upper Body", display(user.strength.upperBody))
//                        ], indent: 24)
//
//                        // Attributes (Power & Stamina included)
//                        Text("Attributes")
//                            .font(.headline)
//                            .padding(.horizontal)
//                        StatsList(items: [
//                            ("Focus", display(user.focus)),
//                            ("Initiative", display(user.initiative)),
//                            ("Discipline", display(user.discipline)),
//                            ("Power", display(user.power)),
//                            ("Stamina", display(user.stamina))
//                        ], indent: 24)
//                    }
//                    .padding(.horizontal)
                }
                .padding(.vertical)
            } else {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading player…")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .navigationTitle("Player")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Logout") {
                    do { try authVM.signOut() }
                    catch { print("Logout failed:", error) }
                }
                .foregroundColor(.red)
            }
        }
    }

    private func display(_ val: Int) -> String {
        val == 0 ? "--" : "\(val)"
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct StatsList: View {
    let items: [(String, String)]
    let indent: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items, id: \.0) { label, value in
                HStack {
                    Text(label).font(.body)
                    Spacer()
                    Text(value).font(.body)
                }
                .padding(.leading, indent)
                .padding(.horizontal)
            }
        }
    }
}



