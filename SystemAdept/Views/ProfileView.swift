//
//  ProfileView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    // State for sign-out errors
    @State private var showSignOutError = false
    @State private var signOutErrorMessage = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if let user = authVM.userProfile {
                VStack(spacing: themeManager.theme.spacingMedium) {
                    // Header: Name & Email
                    HStack(spacing: themeManager.theme.spacingLarge) {
                        Text(user.name)
                            .font(themeManager.theme.headingMediumFont)
                            .bold()
                            .foregroundColor(themeManager.theme.primaryTextColor)
                        Text(user.email)
                            .font(themeManager.theme.bodySmallFont)
                            .foregroundColor(themeManager.theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(themeManager.theme.overlayBackground)
                    .cornerRadius(themeManager.theme.cornerRadius)
                    .padding(.horizontal, themeManager.theme.paddingMedium)

                    // Aura stat
                    StatCard(title: "Aura", value: display(user.aura))
                        .padding(.horizontal, themeManager.theme.paddingMedium)

                    // Rest Cycle Section
                    VStack(alignment: .leading, spacing: themeManager.theme.spacingSmall) {
                        Text("Rest Cycle")
                            .font(themeManager.theme.headingMediumFont)
                            .foregroundColor(themeManager.theme.primaryTextColor)
                        Text(String(
                            format: "%02d:%02d – %02d:%02d",
                            user.restStartHour, user.restStartMinute,
                            user.restEndHour,   user.restEndMinute
                        ))
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(themeManager.theme.primaryTextColor)

                        NavigationLink {
                            RestCycleSettingsView()
                        } label: {
                            Text("Edit Rest Cycle")
                                .font(themeManager.theme.bodySmallFont)
                                .foregroundColor(themeManager.theme.secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(themeManager.theme.overlayBackground)
                    .cornerRadius(themeManager.theme.cornerRadius)
                    .padding(.horizontal, themeManager.theme.paddingMedium)

                    // Logout Button
                    Button(action: {
                        do {
                            try authVM.signOut()
                        } catch {
                            signOutErrorMessage = error.localizedDescription
                            showSignOutError = true
                        }
                    }) {
                        Text("Logout")
                            .font(themeManager.theme.bodyMediumFont)
                            .foregroundColor(themeManager.theme.overlayBackground)
                            .frame(maxWidth: .infinity)
                            .padding(themeManager.theme.spacingMedium)
                            .background(themeManager.theme.secondaryTextColor)
                            .cornerRadius(themeManager.theme.cornerRadius)
                    }
                    .padding(.horizontal, themeManager.theme.paddingMedium)
                    .padding(.top, themeManager.theme.spacingMedium)
                }
                .padding(.vertical, themeManager.theme.spacingMedium)
            } else {
                // Loading state
                VStack(spacing: themeManager.theme.spacingMedium) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.theme.accentPrimary))
                    Text("Loading player…")
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(themeManager.theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(themeManager.theme.paddingMedium)
            }
        }
        // Sign-out error alert
        .alert(isPresented: $showSignOutError) {
            Alert(
                title: Text("Logout Failed"),
                message: Text(signOutErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        // Apply global theme
        .accentColor(themeManager.theme.accentPrimary)
        .font(themeManager.theme.bodyMediumFont)
        .foregroundColor(themeManager.theme.primaryTextColor)
    }

    private func display(_ val: Int) -> String {
        val == 0 ? "--" : "\(val)"
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: themeManager.theme.spacingSmall) {
            Text(title)
                .font(themeManager.theme.headingLargeFont)
                .foregroundColor(themeManager.theme.primaryTextColor)
            Text(value)
                .font(themeManager.theme.bodyLargeFont)
                .bold()
                .foregroundColor(themeManager.theme.accentPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(themeManager.theme.paddingMedium)
        .background(themeManager.theme.overlayBackground)
        .cornerRadius(themeManager.theme.cornerRadius)
    }
}

struct StatsList: View {
    let items: [(String, String)]
    let indent: CGFloat
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: themeManager.theme.spacingSmall) {
            ForEach(items, id: \.0) { label, value in
                HStack {
                    Text(label)
                        .font(themeManager.theme.bodyMediumFont)
                        .foregroundColor(themeManager.theme.primaryTextColor)
                    Spacer()
                    Text(value)
                        .font(themeManager.theme.bodyMediumFont)
                        .foregroundColor(themeManager.theme.primaryTextColor)
                }
                .padding(.leading, indent)
                .padding(.horizontal, themeManager.theme.paddingMedium)
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthViewModel())
            .environmentObject(ThemeManager())
            .background(Color.clear)
    }
}
