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
    
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
//                // Full-screen themed background
//                themeManager.theme.backgroundImage
//                    .resizable()
//                    .scaledToFill()
//                    .ignoresSafeArea()
//
//                // Centered login form
                VStack(spacing: themeManager.theme.spacingMedium) {
                    Spacer(minLength: themeManager.theme.spacingLarge)

                    // Email field
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(themeManager.theme.paddingMedium)
                        .background(themeManager.theme.overlayBackground)
                        .cornerRadius(themeManager.theme.cornerRadius)
                        .font(themeManager.theme.bodyMediumFont)
                        .foregroundColor(themeManager.theme.primaryTextColor)

                    // Password field
                    SecureField("Password", text: $password)
                        .padding(themeManager.theme.paddingMedium)
                        .background(themeManager.theme.overlayBackground)
                        .cornerRadius(themeManager.theme.cornerRadius)
                        .font(themeManager.theme.bodyMediumFont)
                        .foregroundColor(themeManager.theme.primaryTextColor)

                    // Error message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(themeManager.theme.bodySmallFont)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, themeManager.theme.paddingMedium)
                    }

                    // Login button
                    Button("Login") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.theme.accentPrimary)
                    .foregroundColor(.white)
                    .font(themeManager.theme.bodyMediumFont)
                    .padding(.vertical, themeManager.theme.spacingSmall)
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
                .padding(.horizontal, themeManager.theme.spacingMedium)
                .frame(maxWidth: 400)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .font(themeManager.theme.headingMediumFont)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // Apply global theming
        .accentColor(themeManager.theme.accentPrimary)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
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
                .environmentObject(AuthViewModel())
                .environmentObject(ThemeManager())
        }
        .background(Color.clear)
    }
}

