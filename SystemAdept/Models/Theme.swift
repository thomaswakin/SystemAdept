// Models/Theme.swift

import SwiftUI

/// A “design token” bundle that drives colors, fonts, and asset names app-wide.
struct Theme: Decodable {
    // MARK: – Color palette (hex strings)
    let primaryColorHex: String
    let secondaryColorHex: String
    let accentColorHex: String

    // MARK: – Typography
    let headingFontName: String
    let bodyFontName: String

    // MARK: – Spacings & Corners
    let cornerRadius: CGFloat

    // MARK: – Asset groups
    let iconSetName: String
    
    /// The asset name of the full‐screen background image
    let backgroundImageName: String

    // Convenience: convert hex to SwiftUI Color
    func color(from hex: String) -> Color {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 {
            hex = "FF" + hex
        }
        let int = UInt64(hex, radix: 16) ?? 0
        let a = Double((int & 0xFF000000) >> 24) / 255
        let r = Double((int & 0x00FF0000) >> 16) / 255
        let g = Double((int & 0x0000FF00) >> 8 ) / 255
        let b = Double( int & 0x000000FF       ) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // Typed accessors
    var primaryColor: Color { color(from: primaryColorHex) }
    var secondaryColor: Color { color(from: secondaryColorHex) }
    var accentColor:    Color { color(from: accentColorHex) }
    
    // Typed Font getters
    var bodyVerySmallFont:  Font { .custom(bodyFontName, size: fontSizeVerySmall) }
    var bodySmallFont:  Font { .custom(bodyFontName, size: fontSizeSmall) }
    var bodyMediumFont: Font { .custom(bodyFontName, size: fontSizeMedium) }
    var bodyLargeFont: Font { .custom(bodyFontName, size: fontSizeLarge) }
    var headingVerySmallFont: Font { .custom(headingFontName, size: fontSizeVerySmall) }
    var headingSmallFont:  Font { .custom(headingFontName, size: fontSizeSmall) }
    var headingMediumFont:  Font { .custom(headingFontName, size: fontSizeMedium) }
    var headingLargeFont:  Font { .custom(headingFontName, size: fontSizeLarge) }
    
    // MARK: – Size tokens
    let fontSizeVerySmall: CGFloat
    let fontSizeSmall:  CGFloat
    let fontSizeMedium: CGFloat
    let fontSizeLarge:  CGFloat
    
    // MARK: - padding
    let spacingSmall:   CGFloat
    let spacingMedium:  CGFloat
    let spacingLarge:   CGFloat

    var paddingSmall:  CGFloat { spacingSmall }   // 4
    var paddingMedium: CGFloat { spacingMedium }  // 8
    var paddingLarge:  CGFloat { spacingLarge }   // 16
    
    /// The SwiftUI Image for our app’s background
    var backgroundImage: Image {
        Image(backgroundImageName)
    }
}

