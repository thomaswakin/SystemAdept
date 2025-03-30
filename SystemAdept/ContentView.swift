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
        NavigationStack {
            if isAuthenticated {
                // Main content for authenticated users
                VStack(spacing: 20) {
                    Text("Welcome to System Adept!")
                        .font(.largeTitle)
                        .foregroundColor(.black)
                    
                    NavigationLink("Edit Profile", destination: EditProfileView())
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    
                    Button("Sign Out") {
                        signOut()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .navigationTitle("Home")
            } else {
                // Display login/register options (assume you have these views)
                VStack(spacing: 20) {
                    NavigationLink("Login", destination: LoginView())
                        .buttonStyle(.borderedProminent)
                    NavigationLink("Register", destination: RegisterView())
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .navigationTitle("Welcome")
            }
        }
        .onAppear {
            self.isAuthenticated = AuthService.shared.isUserLoggedIn()
        }
    }
    
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
