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
import FirebaseAuthUI

@main
struct SystemAdeptApp: App {
    init() {
        FirebaseApp.configure()
        let authUI = FUIAuth.defaultAuthUI()
        // You need to adopt a FUIAuthDelegate protocol to receive callback
        authUI.delegate = self
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView() // Your initial view
        }
    }
}
