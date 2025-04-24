//
//  RegisterView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//

import SwiftUI
import FirebaseAuth

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isRegistered = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Email input field
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                // Password input field
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                // Confirm password input field
                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                // Error message display
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Register button
                Button(action: {
                    register()
                }) {
                    Text("Register")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                NavigationLink(destination: ContentView(), isActive: $isRegistered) {
                    EmptyView()
                }
            }
            .padding()
            .navigationTitle("Register")
        }
    }
    
    private func register() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            if let user = authResult?.user {
                // Ensure a default profile exists for the new user.
                UserProfileService.shared.ensureUserProfile(for: user.uid, email: user.email ?? "") { profile, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        print("User profile ensured for \(user.uid)")
                        DispatchQueue.main.async {
                            self.isRegistered = true
                        }
                    }
                }
            }
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
    }
}
