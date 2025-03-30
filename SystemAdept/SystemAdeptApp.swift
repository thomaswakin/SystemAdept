//
//  SystemAdeptApp.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth


@main
struct SystemAdeptApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView() // Your initial view
        }
    }
}
