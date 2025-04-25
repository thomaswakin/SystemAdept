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
                // 1) Background
                themeManager.theme.backgroundImage
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // 2) Content
                VStack(spacing: themeManager.theme.spacingMedium) {
                    Spacer()
                        .frame(height: 80)
                    // Custom title in-content, lower on screen
                    // Full-width header bar
                    Text(showLogin ? "Login" : "Register")
                        .font(themeManager.theme.headingLargeFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)                  // stretch across the container
                        .padding(.vertical, themeManager.theme.spacingSmall)
                        .background(themeManager.theme.secondaryTextColor).opacity(0.8)
                        .padding(.horizontal, -themeManager.theme.spacingMedium)
                        // note: negative padding to bleed into the screen edges
                        // (or use .ignoresSafeArea(edges: .horizontal) on the bar)

                    // Toggle Picker
                    Picker("", selection: $showLogin) {
                        Text("Login").tag(true)
                        Text("Register").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .tint(themeManager.theme.accentPrimary)
                    .font(themeManager.theme.bodySmallFont)
                    .padding(.vertical, themeManager.theme.spacingMedium)

                    Group {
                        if showLogin {
                            LoginView()
                        } else {
                            RegisterView()
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, themeManager.theme.spacingMedium)
                .frame(maxWidth: 400)
            }
            // 3) Remove default nav title
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Empty so UIKit doesn’t draw its own title
                    EmptyView()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
            .environmentObject(ThemeManager())
    }
}
