//
//  ThemeManager.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/23/25.
//

import Foundation
import SwiftUI
import Combine
import UIKit

/// Manages the active Theme, loading from a bundled JSON and applying UI appearances.
final class ThemeManager: ObservableObject {
    @Published private(set) var theme: Theme {
        didSet {
            applyNavigationBarAppearance()
            applyTabBarAppearance()
        }
    }
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 1) Load default theme from bundle
        if let loaded = ThemeManager.loadBundleTheme(named: "Light") {
            self.theme = loaded
        } else {
            // Fallback defaults
            self.theme = Theme(
                primaryColorHex:        "1E88E5",
                secondaryColorHex:      "424242",
                accentColorHex:         "FFC107",
                primaryTextColorHex:    "263238",
                secondaryTextColorHex:  "607D8B",
                accentPrimaryHex:       "FFB300",
                accentSecondaryHex:     "00838F",
                overlayBackgroundRGBA:  [255, 255, 255, 0.8],
                headingFontName:        "Copperplate",
                bodyFontName:           "Futura-Medium",
                cornerRadius:           8,
                iconSetName:            "DefaultIcons",
                backgroundImageName:    "background",
                fontSizeVerySmall:      8,
                fontSizeSmall:          12,
                fontSizeMedium:         16,
                fontSizeLarge:          24,
                spacingSmall:           4,
                spacingMedium:          8,
                spacingLarge:           16
            )
        }

        // 2) Apply initial appearances
        applyNavigationBarAppearance()
        applyTabBarAppearance()

        // 3) Optionally fetch remote theme override
        fetchRemoteTheme()
        
        // IOS 16 Suppport
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        
    }

    /// Loads a Theme JSON from the main bundle by name.
    static func loadBundleTheme(named name: String) -> Theme? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Theme.self, from: data)
        } catch {
            print("❌ Failed to load theme bundle: \(error)")
            return nil
        }
    }

    /// Stub for fetching/theme updates remotely.
    private func fetchRemoteTheme() {
        // e.g. use Firebase Remote Config or Firestore to fetch new JSON
    }

    /// Applies the current theme to UINavigationBar.
    func applyNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()   // ← transparent instead of opaque

        let uiPrimary = UIColor(theme.primaryColor)
        let navFont   = UIFont(
            name: theme.headingFontName,
            size: theme.fontSizeLarge
        ) ?? .systemFont(ofSize: theme.fontSizeLarge)

        appearance.titleTextAttributes      = [
          .foregroundColor: uiPrimary,
          .font:            navFont
        ]
        appearance.largeTitleTextAttributes = appearance.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance  = appearance
        UINavigationBar.appearance().compactAppearance     = appearance
    }

    func applyTabBarAppearance() {
        let uiPrimary = UIColor(theme.primaryColor)
        let uiAccent  = UIColor(theme.accentColor)
        let uiFont    = UIFont(
            name: theme.bodyFontName,
            size: theme.fontSizeSmall
        ) ?? .systemFont(ofSize: theme.fontSizeSmall)

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()   // ← transparent instead of opaque

        // Unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font:            uiFont,
            .foregroundColor: uiPrimary
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = uiPrimary

        // Selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font:            uiFont,
            .foregroundColor: uiAccent
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = uiAccent

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
