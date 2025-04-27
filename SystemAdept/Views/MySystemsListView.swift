//
//  MySystemsListView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/24/25.
//


import SwiftUI

struct MySystemsListView: View {
    @EnvironmentObject private var activeSystemsVM: ActiveSystemsViewModel
    @EnvironmentObject private var themeManager:    ThemeManager

    var body: some View {
        List {
            ForEach(activeSystemsVM.activeSystems) { system in
                HStack {
                    Text(system.questSystemName)
                        .font(themeManager.theme.bodyMediumFont)
                    Spacer()
                    // show current status inline if you like
                    Text(system.status.rawValue.capitalized)
                        .font(themeManager.theme.bodySmallFont)
                        .foregroundColor(themeManager.theme.secondaryColor)
                }
                .padding(.vertical, themeManager.theme.spacingSmall)
                // Move Pause/Resume + Stop into one swipe gesture per row
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        activeSystemsVM.togglePause(system: system)
                    } label: {
                        Text(system.status == .active ? "Pause" : "Resume")
                    }
                    .tint(themeManager.theme.accentColor)

                    Button(role: .destructive) {
                        activeSystemsVM.stop(system: system)
                    } label: {
                        Text("Stop")
                    }
                }
                .listRowBackground(Color.white.opacity(0.9))
                .cornerRadius(themeManager.theme.cornerRadius)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

struct MySystemsListView_Previews: PreviewProvider {
    static var previews: some View {
        MySystemsListView()
            .environmentObject(ThemeManager())
    }
}
