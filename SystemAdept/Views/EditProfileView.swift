//
//  EditProfileView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//


import SwiftUI
import FirebaseAuth

struct EditProfileView: View {
    @State private var profile: UserProfile?
    @State private var newName: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = true
    @State private var showSuccessMessage: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading...")
            } else if let profile = profile {
                VStack(alignment: .leading, spacing: 10) {
                    // Display read-only fields
                    Text("Email: \(profile.email)")
                    HStack {
                        Text("Name: ")
                        TextField("Enter name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Text("Aura: \(profile.aura)")
                    Text("Skill Points: \(profile.skillPoints)")
                    
                    // Display metrics
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Strength:")
                        Text("  Upper Body: \(profile.strength.upperBody)")
                        Text("  Core: \(profile.strength.core)")
                        Text("  Lower Body: \(profile.strength.lowerBody)")
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Agility:")
                        Text("  Flexibility: \(profile.agility.flexibility)")
                        Text("  Speed: \(profile.agility.speed)")
                        Text("  Balance: \(profile.agility.balance)")
                    }
                    Text("Stamina: \(profile.stamina)")
                    Text("Power: \(profile.power)")
                    Text("Focus: \(profile.focus)")
                    Text("Discipline: \(profile.discipline)")
                    Text("Initiative: \(profile.initiative)")
                }
                .padding()
                
                Button("Update Name") {
                    updateProfile()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                if showSuccessMessage {
                    Text("Profile updated successfully!")
                        .foregroundColor(.green)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            } else {
                Text("Profile not found.")
            }
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            loadProfile()
        }
    }
    
    // Fetch the current user's profile
    private func loadProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in."
            isLoading = false
            return
        }
        UserProfileService.shared.fetchUserProfile(for: uid) { profile, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else if let profile = profile {
                    self.profile = profile
                    self.newName = profile.name
                }
            }
        }
    }
    
    // Update the user's name in Firestore
    private func updateProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in."
            return
        }
        UserProfileService.shared.updateUserProfile(name: newName, for: uid) { error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    showSuccessMessage = true
                    self.profile?.name = newName
                }
            }
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EditProfileView()
        }
        .background(Color.clear)
    }
}
