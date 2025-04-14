//
//  ProfileView.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import SwiftUI

struct ProfileView: View {
  @EnvironmentObject var authVM: AuthViewModel

  var body: some View {
    VStack(spacing: 20) {
      if let user = authVM.user {
        Text("Hello, \(user.email ?? "User")")
          .font(.title2)
      }
      Button("Logout") {
        do {
          try authVM.signOut()
        } catch {
          // handle error
        }
      }
      .foregroundColor(.red)
    }
    .padding()
  }
}