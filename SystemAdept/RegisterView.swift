//
//  RegisterView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//


import SwiftUI

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isRegistered = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Email input field
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                // Password input field
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                // Confirm password input field
                SecureField("Confirm Password", text: $confirmPassword)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                // Display error messages if any.
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
                
                // NavigationLink to the main content after successful registration.
                NavigationLink(destination: ContentView(), isActive: $isRegistered) {
                    EmptyView()
                }
            }
            .padding()
            .navigationTitle("Register")
        }
    }
    
    // Validate input and call AuthService to register the user.
    private func register() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        AuthService.shared.registerUser(email: email, password: password) { result in
            switch result {
            case .success(let authResult):
                print("User registered: \(authResult.user.uid)")
                DispatchQueue.main.async {
                    self.isRegistered = true
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
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
