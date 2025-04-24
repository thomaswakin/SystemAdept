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

    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            VStack(spacing: themeManager.theme.spacingMedium) {
                Spacer(minLength: themeManager.theme.spacingLarge)

                // Email input field
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(themeManager.theme.paddingMedium)
                    .background(themeManager.theme.overlayBackground)
                    .cornerRadius(themeManager.theme.cornerRadius)
                    .font(themeManager.theme.bodyMediumFont)
                    .foregroundColor(themeManager.theme.primaryTextColor)

                // Password input field
                SecureField("Password", text: $password)
                    .padding(themeManager.theme.paddingMedium)
                    .background(themeManager.theme.overlayBackground)
                    .cornerRadius(themeManager.theme.cornerRadius)
                    .font(themeManager.theme.bodyMediumFont)
                    .foregroundColor(themeManager.theme.primaryTextColor)

                // Confirm password input field
                SecureField("Confirm Password", text: $confirmPassword)
                    .padding(themeManager.theme.paddingMedium)
                    .background(themeManager.theme.overlayBackground)
                    .cornerRadius(themeManager.theme.cornerRadius)
                    .font(themeManager.theme.bodyMediumFont)
                    .foregroundColor(themeManager.theme.primaryTextColor)

                // Error message display
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, themeManager.theme.paddingMedium)
                }

                // Register button
                Button(action: {
                    register()
                }) {
                    Text("Register")
                        .font(themeManager.theme.bodyMediumFont)
                        .foregroundColor(.white)
                        .padding(.vertical, themeManager.theme.spacingSmall)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.theme.accentSecondary)
                .cornerRadius(themeManager.theme.cornerRadius)

                // Navigation on success
                NavigationLink(destination: ContentView(), isActive: $isRegistered) {
                    EmptyView()
                }

                Spacer()
            }
            .padding(.horizontal, themeManager.theme.paddingMedium)
            .frame(maxWidth: 400)
            .navigationTitle("Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // Apply global theming
        .accentColor(themeManager.theme.accentSecondary)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
    }

    private func register() {
        guard !email.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            if let user = result?.user {
                UserProfileService.shared.ensureUserProfile(for: user.uid, email: user.email ?? "") { profile, err in
                    if let err = err {
                        errorMessage = err.localizedDescription
                    } else {
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
        NavigationStack {
            RegisterView()
                .environmentObject(AuthViewModel())
                .environmentObject(ThemeManager())
        }
        .background(Color.clear)
    }
}
