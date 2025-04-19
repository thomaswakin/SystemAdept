//
//  RestCycleSettingsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/18/25.
//

import SwiftUI
import FirebaseAuth

struct RestCycleSettingsView: View {
    // MARK: Environment
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var authVM: AuthViewModel

    // MARK: State
    @State private var startTime = Date()
    @State private var endTime   = Date()
    @State private var errorMsg  = ""

    // convenience
    private var uid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        Form {
            Section(header: Text("Rest Start")) {
                DatePicker(
                    "Start Time",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )
            }

            Section(header: Text("Rest End")) {
                DatePicker(
                    "End Time",
                    selection: $endTime,
                    displayedComponents: .hourAndMinute
                )
            }

            if !errorMsg.isEmpty {
                Text(errorMsg)
                    .foregroundColor(.red)
            }

            Button("Save") {
                saveRestCycle()
            }
            .disabled(uid == nil)
        }
        .navigationTitle("Rest Cycle")
        .onAppear {
            loadCurrentValues()
        }
    }

    // MARK: Helpers

    /// Pull `restStartHour`/`restStartMinute` and `restEndHour`/`restEndMinute`
    /// from the signed‑in user’s profile and populate our pickers.
    private func loadCurrentValues() {
        guard let profile = authVM.userProfile else { return }

        // build a Date just for the time of day
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = profile.restStartHour
        comps.minute = profile.restStartMinute
        if let d1 = Calendar.current.date(from: comps) {
            startTime = d1
        }

        comps.hour   = profile.restEndHour
        comps.minute = profile.restEndMinute
        if let d2 = Calendar.current.date(from: comps) {
            endTime = d2
        }
    }

    /// Extract hour/minute from our pickers and send to Firestore.
    private func saveRestCycle() {
        guard let uid = uid else { return }

        let c1 = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        let c2 = Calendar.current.dateComponents([.hour, .minute], from: endTime)

        guard
            let h1 = c1.hour,   let m1 = c1.minute,
            let h2 = c2.hour,   let m2 = c2.minute
        else { return }

        UserProfileService.shared.updateRestCycle(
            startHour:   h1,
            startMinute: m1,
            endHour:     h2,
            endMinute:   m2,
            for:         uid
        ) { error in
            if let error = error {
                errorMsg = error.localizedDescription
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
