//
//  LoginView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button("Login") {
                    login()
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(8)
                
                NavigationLink(destination: ContentView(), isActive: $isLoggedIn) {
                    EmptyView()
                }
            }
            .padding()
            .navigationTitle("Login")
        }
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            if let user = authResult?.user {
                // Ensure a profile exists for this existing user.
                UserProfileService.shared.ensureUserProfile(for: user.uid, email: user.email ?? "") { profile, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        print("User profile ensured for \(user.uid)")
                        DispatchQueue.main.async {
                            self.isLoggedIn = true
                        }
                    }
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoginView()
        }
        .background(Color.clear)
    }
}
