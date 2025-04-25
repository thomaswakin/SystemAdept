//
//  ContentView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var isAuthenticated = AuthService.shared.isUserLoggedIn()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen themed background
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Main content
                if isAuthenticated {
                    VStack(spacing: themeManager.theme.spacingMedium) {
                        Spacer(minLength: themeManager.theme.spacingLarge)

                        // Welcome headline
                        Text("Welcome to System Adept!")
                            .font(themeManager.theme.headingLargeFont)
                            .foregroundColor(themeManager.theme.primaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, themeManager.theme.spacingMedium)

                        // Edit Profile button
                        NavigationLink(destination: EditProfileView()) {
                            Text("Edit Profile")
                                .font(themeManager.theme.bodyMediumFont)
                                .foregroundColor(.white)
                                .padding(.vertical, themeManager.theme.spacingSmall)
                                .frame(maxWidth: .infinity)
                                .background(themeManager.theme.accentPrimary)
                                .cornerRadius(themeManager.theme.cornerRadius)
                        }

                        // Sign Out button
                        Button(action: signOut) {
                            Text("Sign Out")
                                .font(themeManager.theme.bodyMediumFont)
                                .foregroundColor(.white)
                                .padding(.vertical, themeManager.theme.spacingSmall)
                                .frame(maxWidth: .infinity)
                                .background(themeManager.theme.accentSecondary)
                                .cornerRadius(themeManager.theme.cornerRadius)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, themeManager.theme.spacingMedium)
                    .frame(maxWidth: 400)
                } else {
                    // Not authenticated: show Login / Register options
                    VStack(spacing: themeManager.theme.spacingMedium) {
                        Spacer(minLength: themeManager.theme.spacingLarge)

                        NavigationLink("Login", destination: LoginView())
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.theme.accentPrimary)

                        NavigationLink("Register", destination: RegisterView())
                            .buttonStyle(.borderedProminent)
                            .tint(themeManager.theme.accentSecondary)

                        Spacer()
                    }
                    .padding(.horizontal, themeManager.theme.spacingMedium)
                    .frame(maxWidth: 400)
                }
            }
            // Remove default nav title
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // Apply global theme styles
        .accentColor(themeManager.theme.accentPrimary)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
        .onAppear {
            self.isAuthenticated = AuthService.shared.isUserLoggedIn()
        }
    }

    private func signOut() {
        do {
            try AuthService.shared.signOut()
            isAuthenticated = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ThemeManager())
    }
}

