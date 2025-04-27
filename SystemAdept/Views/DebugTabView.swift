//
//  DebugTabView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/25/25.
//


import SwiftUI

/// A simple debug view to verify a multi-tab setup over a background image.
struct DebugTabView: View {
    var body: some View {
        TabView {
            // Home Tab
            ZStack {
                Image("ciruit")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()  // behind notch only
                Text("Home Screen")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            // Settings Tab
            ZStack {
                Image("circuit")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Text("Settings Screen")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }

            // Profile Tab
            ZStack {
                Image("circuit")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Text("Profile Screen")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .background(Color.clear)
    }
}

struct DebugTabView_Previews: PreviewProvider {
    static var previews: some View {
        DebugTabView()
    }
}
