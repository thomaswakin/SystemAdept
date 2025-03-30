//
//  ContentView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/29/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var isAuthenticated = AuthService.shared.isUserLoggedIn()
    
    var body: some View {
        NavigationView {
            if isAuthenticated {
                // Main content for authenticated users.
                VStack(spacing: 20) {
                    Text("Welcome to System Adept!")
                        .font(.largeTitle)
                    Button("Sign Out") {
                        signOut()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .navigationTitle("Home")
            } else {
                // Navigation options for users who are not signed in.
                VStack(spacing: 20) {
                    NavigationLink(destination: LoginView()) {
                        Text("Login")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    NavigationLink(destination: RegisterView()) {
                        Text("Register")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .navigationTitle("Welcome")
            }
        }
        .onAppear {
            // Check the user's authentication status when the view appears.
            self.isAuthenticated = AuthService.shared.isUserLoggedIn()
        }
    }
    
    // Sign out the current user.
    private func signOut() {
        do {
            try AuthService.shared.signOut()
            isAuthenticated = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
