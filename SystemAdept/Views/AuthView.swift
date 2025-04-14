//
//  AuthView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import SwiftUI

struct AuthView: View {
  @EnvironmentObject var authVM: AuthViewModel
  @State private var showLogin = true

  var body: some View {
    NavigationView {
      VStack {
        Picker("", selection: $showLogin) {
          Text("Login").tag(true)
          Text("Register").tag(false)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()

        if showLogin {
          LoginView()
        } else {
          RegisterView()
        }
      }
      .navigationTitle(showLogin ? "Login" : "Register")
    }
  }
}