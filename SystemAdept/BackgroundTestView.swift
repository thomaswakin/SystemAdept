//
//  BackgroundTestView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/24/25.
//


import SwiftUI

struct BackgroundTestView: View {
  @EnvironmentObject private var themeManager: ThemeManager

  var body: some View {
    ZStack {
      // 1️⃣ The background image
      themeManager.theme.backgroundImage
        .ignoresSafeArea()

      // 2️⃣ A single centered label
      Text("👀 Is the BG visible?")
        .font(.largeTitle)
        .padding()
        .background(Color.white.opacity(0.75))
        .cornerRadius(8)
    }
  }
}

struct BackgroundTestView_Previews: PreviewProvider {
  static var previews: some View {
    BackgroundTestView()
      .environmentObject(ThemeManager())
  }
}