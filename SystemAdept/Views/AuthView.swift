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

                // 2) Centered login/register UI with extra top padding
                VStack(spacing: themeManager.theme.spacingMedium) {
                    Picker("", selection: $showLogin) {
                        Text("Login").tag(true)
                        Text("Register").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .tint(themeManager.theme.accentPrimary)
                    .font(themeManager.theme.bodySmallFont)
                    .padding(.bottom, themeManager.theme.spacingMedium)

                    // Show Login or Register form
                    Group {
                        if showLogin {
                            LoginView()
                        } else {
                            RegisterView()
                        }
                    }
                    .background(Color.clear)

                    Spacer()
                }
                .padding(.top, themeManager.theme.spacingLarge * 10)  // push below notch
                .padding(.horizontal, themeManager.theme.spacingMedium)
                .frame(maxWidth: 400)
            }
            .navigationTitle(showLogin ? "Login" : "Register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        // Global theming
        .accentColor(themeManager.theme.accentPrimary)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
            .environmentObject(ThemeManager())
    }
}
