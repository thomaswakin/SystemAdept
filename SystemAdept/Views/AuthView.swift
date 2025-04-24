//
//  AuthView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.

import SwiftUI

struct AuthView: View {
    @State private var showLogin = true
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
                // 1) Full-screen themed background
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // 2) Centered login/register UI
                VStack(spacing: themeManager.theme.spacingMedium) {
                    Spacer(minLength: themeManager.theme.spacingLarge)

                    // Segmented control tinted with accentPrimary color and themed font
                    Picker("", selection: $showLogin) {
                        Text("Login").tag(true)
                            .tint(themeManager.theme.accentPrimary)
                            .font(themeManager.theme.bodySmallFont)
                        Text("Register").tag(false)
                            .tint(themeManager.theme.accentPrimary)
                            .font(themeManager.theme.bodySmallFont)
                    }
                    .pickerStyle(.segmented)
                    .tint(themeManager.theme.accentPrimary)
                    .font(themeManager.theme.bodySmallFont)
                    .padding(themeManager.theme.spacingMedium)

                    // Show Login or Register form
                    Group {
                        if showLogin {
                            LoginView()
                        } else {
                            RegisterView()
                        }
                    }
                    .background(Color.clear)
                    .padding(.top, themeManager.theme.spacingMedium)
                    .foregroundColor(themeManager.theme.primaryTextColor)

                    Spacer()
                }
                .padding(.horizontal, themeManager.theme.spacingMedium)
                .frame(maxWidth: 400)
            }
            .navigationTitle(showLogin ? "Login" : "Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)  // iOS 16+ transparent bar
        }
        // Global theming: accent and text colors
        .accentColor(themeManager.theme.accentPrimary)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
    }
}
