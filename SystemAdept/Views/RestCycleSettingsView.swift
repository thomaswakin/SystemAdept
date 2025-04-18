//
//  RestCycleSettingsView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/18/25.
//


//
//  RestCycleSettingsView.swift
//  SystemAdept
//

import SwiftUI
import FirebaseAuth

struct RestCycleSettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var startTime = Date()
    @State private var endTime   = Date()
    @State private var errorMsg  = ""

    private var uid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        Form {
            Section(header: Text("Rest Start")) {
                DatePicker(
                    "Start Time",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
            }
            Section(header: Text("Rest End")) {
                DatePicker(
                    "End Time",
                    selection: $endTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
            }
            if !errorMsg.isEmpty {
                Section { Text(errorMsg).foregroundColor(.red) }
            }
            Section {
                Button("Save") {
                    saveCycle()
                }
            }
        }
        .navigationTitle("Rest Cycle")
        .onAppear(perform: loadCurrentCycle)
    }

    private func loadCurrentCycle() {
        guard
            let user = AuthViewModel().userProfile
        else { return }
        let cal = Calendar.current
        if let d1 = cal.date(
            bySettingHour:   user.restStartHour,
                         minute: user.restStartMinute,
                         second: 0, of: Date()
        ) {
            startTime = d1
        }
        if let d2 = cal.date(
            bySettingHour:   user.restEndHour,
                         minute: user.restEndMinute,
                         second: 0, of: Date()
        ) {
            endTime = d2
        }
    }

    private func saveCycle() {
        guard let uid = uid else {
            errorMsg = "Not logged in"
            return
        }
        let cal = Calendar.current
        let h1 = cal.component(.hour, from: startTime)
        let m1 = cal.component(.minute, from: startTime)
        let h2 = cal.component(.hour, from: endTime)
        let m2 = cal.component(.minute, from: endTime)

        UserProfileService.shared.updateRestCycle(
            startHour:   h1,
            startMinute: m1,
            endHour:     h2,
            endMinute:   m2,
            for: uid
        ) { error in
            if let error = error {
                errorMsg = error.localizedDescription
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}