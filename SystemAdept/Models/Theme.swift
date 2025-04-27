// Models/Theme.swift

import SwiftUI

/// A “design token” bundle that drives colors, fonts, and asset names app-wide.
struct Theme: Decodable {
    // MARK: - Color palette (hex strings)
    let primaryColorHex: String
    let secondaryColorHex: String
    let accentColorHex: String

    // New text & additional accent colors
    let primaryTextColorHex: String
    let secondaryTextColorHex: String
    let accentPrimaryHex: String
    let accentSecondaryHex: String

    // Overlay (RGBA) for semi-transparent panels
    let overlayBackgroundRGBA: [Double]

    // MARK: - Typography
    let headingFontName: String
    let bodyFontName: String

    // MARK: - Spacings & Corners
    let cornerRadius: CGFloat

    // MARK: - Asset groups
    let iconSetName: String
    /// The asset name of the full-screen background image
    let backgroundImageName: String

    // MARK: - Size tokens
    let fontSizeVerySmall: CGFloat
    let fontSizeSmall: CGFloat
    let fontSizeMedium: CGFloat
    let fontSizeLarge: CGFloat
    let fontSizeXtraLarge: CGFloat

    // Padding shorthand
    let spacingSmall: CGFloat
    let spacingMedium: CGFloat
    let spacingLarge: CGFloat

    // MARK: - Decodable synthesized keys
    private enum CodingKeys: String, CodingKey {
        case primaryColorHex, secondaryColorHex, accentColorHex
        case primaryTextColorHex, secondaryTextColorHex, accentPrimaryHex, accentSecondaryHex
        case overlayBackgroundRGBA
        case headingFontName, bodyFontName
        case cornerRadius
        case iconSetName, backgroundImageName
        case fontSizeVerySmall, fontSizeSmall, fontSizeMedium, fontSizeLarge, fontSizeXtraLarge
        case spacingSmall, spacingMedium, spacingLarge
    }

    // MARK: - Hex → Color converter
    func color(from hex: String) -> Color {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 { hex = "FF" + hex }
        let int = UInt64(hex, radix: 16) ?? 0
        let a = Double((int & 0xFF000000) >> 24) / 255
        let r = Double((int & 0x00FF0000) >> 16) / 255
        let g = Double((int & 0x0000FF00) >> 8 ) / 255
        let b = Double( int & 0x000000FF       ) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - Typed accessors
    var primaryColor: Color    { color(from: primaryColorHex) }
    var secondaryColor: Color  { color(from: secondaryColorHex) }
    var accentColor: Color     { color(from: accentColorHex) }

    var primaryTextColor: Color   { color(from: primaryTextColorHex) }
    var secondaryTextColor: Color { color(from: secondaryTextColorHex) }

    var accentPrimary: Color   { color(from: accentPrimaryHex) }
    var accentSecondary: Color { color(from: accentSecondaryHex) }

    var overlayBackground: Color {
        guard overlayBackgroundRGBA.count == 4 else {
            return Color.white.opacity(0.8)
        }
        return Color(.sRGB,
                     red:   overlayBackgroundRGBA[0]/255,
                     green: overlayBackgroundRGBA[1]/255,
                     blue:  overlayBackgroundRGBA[2]/255,
                     opacity: overlayBackgroundRGBA[3])
    }

    // MARK: - Font getters
    // body variants
    var bodyVerySmallFont:  Font { .custom(bodyFontName, size: fontSizeVerySmall, relativeTo: .caption2) }
    var bodySmallFont:      Font { .custom(bodyFontName, size: fontSizeSmall,     relativeTo: .footnote) }
    var bodyMediumFont:     Font { .custom(bodyFontName, size: fontSizeMedium,    relativeTo: .body) }
    var bodyLargeFont:      Font { .custom(bodyFontName, size: fontSizeLarge,     relativeTo: .title3) }
    var bodyXtraLargeFont:      Font { .custom(bodyFontName, size: fontSizeXtraLarge,     relativeTo: .title2) }

    // heading variants
    var headingVerySmallFont: Font { .custom(headingFontName, size: fontSizeVerySmall, relativeTo: .caption) }
    var headingSmallFont:     Font { .custom(headingFontName, size: fontSizeSmall,     relativeTo: .callout) }
    var headingMediumFont:    Font { .custom(headingFontName, size: fontSizeMedium,    relativeTo: .headline) }
    var headingLargeFont:     Font { .custom(headingFontName, size: fontSizeLarge,     relativeTo: .largeTitle) }
    var headingXtraLargeFont:     Font { .custom(headingFontName, size: fontSizeXtraLarge, relativeTo: .title2) }

    // MARK: - Padding shortcuts
    var paddingSmall:  CGFloat { spacingSmall }
    var paddingMedium: CGFloat { spacingMedium }
    var paddingLarge:  CGFloat { spacingLarge }

    /// The SwiftUI Image for our app’s background
    var backgroundImage: Image { Image(backgroundImageName) }
}
