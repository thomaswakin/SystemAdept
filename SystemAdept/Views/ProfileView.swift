//
//  ProfileView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showingRestCycleSheet = false
    @State private var restStart = Date()
    @State private var restEnd = Date()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let user = authVM.userProfile {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.largeTitle)
                            .bold()
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Aura
                    StatCard(title: "Aura", value: display(user.aura))
                        .padding(.horizontal)

                    // Rest Cycle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Cycle")
                            .font(.headline)
                            .padding(.horizontal)
                        HStack {
                            Text(
                                formatTime(hour: user.restCycle.startHour,
                                           minute: user.restCycle.startMinute)
                                + " – " +
                                formatTime(hour: user.restCycle.endHour,
                                           minute: user.restCycle.endMinute)
                            )
                            Spacer()
                            Button("Edit") {
                                showingRestCycleSheet = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal)
                    }

                    // Skill Points / Stats (unchanged)…
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Skill Points")
                            .font(.title2).bold()
                            .padding(.horizontal)

                        Text("Agility")
                            .font(.headline).padding(.horizontal)
                        StatsList(items: [
                            ("Speed", display(user.agility.speed)),
                            ("Balance", display(user.agility.balance)),
                            ("Flexibility", display(user.agility.flexibility))
                        ], indent: 24)

                        Text("Strength")
                            .font(.headline).padding(.horizontal)
                        StatsList(items: [
                            ("Core", display(user.strength.core)),
                            ("Lower Body", display(user.strength.lowerBody)),
                            ("Upper Body", display(user.strength.upperBody))
                        ], indent: 24)

                        Text("Attributes")
                            .font(.headline).padding(.horizontal)
                        StatsList(items: [
                            ("Focus", display(user.focus)),
                            ("Initiative", display(user.initiative)),
                            ("Discipline", display(user.discipline)),
                            ("Power", display(user.power)),
                            ("Stamina", display(user.stamina))
                        ], indent: 24)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .onAppear {
                    let cal = Calendar.current
                    restStart = cal.date(
                        bySettingHour: user.restCycle.startHour,
                        minute: user.restCycle.startMinute,
                        second: 0,
                        of: Date()
                    ) ?? Date()
                    restEnd = cal.date(
                        bySettingHour: user.restCycle.endHour,
                        minute: user.restCycle.endMinute,
                        second: 0,
                        of: Date()
                    ) ?? Date()
                }
            } else {
                // Loading
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading player…")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Player")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Logout") {
                    try? authVM.signOut()
                }
                .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showingRestCycleSheet) {
            NavigationStack {
                Form {
                    DatePicker(
                        "Start",
                        selection: $restStart,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "End",
                        selection: $restEnd,
                        displayedComponents: .hourAndMinute
                    )
                }
                .navigationTitle("Rest Cycle")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingRestCycleSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let cal = Calendar.current
                            let sh = cal.component(.hour,   from: restStart)
                            let sm = cal.component(.minute, from: restStart)
                            let eh = cal.component(.hour,   from: restEnd)
                            let em = cal.component(.minute, from: restEnd)
                            authVM.setRestCycle(
                                startHour: sh,
                                startMinute: sm,
                                endHour: eh,
                                endMinute: em
                            )
                            showingRestCycleSheet = false
                        }
                    }
                }
            }
        }
    }

    private func display(_ val: Int) -> String {
        val == 0 ? "--" : "\(val)"
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(.dateTime.hour().minute())
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



