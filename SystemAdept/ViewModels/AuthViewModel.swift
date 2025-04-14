//
//  AuthViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//


import Foundation
import FirebaseAuth
import Combine

final class AuthViewModel: ObservableObject {
  @Published var user: User? = nil
  private var handle: AuthStateDidChangeListenerHandle?

  init() {
    handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
      self?.user = user
    }
  }
  deinit {
    if let handle = handle {
      Auth.auth().removeStateDidChangeListener(handle)
    }
  }

  var isLoggedIn: Bool { user != nil }

  func signOut() throws {
    try Auth.auth().signOut()
  }
}