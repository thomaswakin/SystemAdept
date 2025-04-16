//
//  AuthViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class AuthViewModel: ObservableObject {
    @Published var firebaseUser: FirebaseAuth.User?
    @Published var userProfile: AppUser?
    var isLoggedIn: Bool { firebaseUser != nil }

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.firebaseUser = user
            self?.attachUserListener(for: user?.uid)
        }
    }

    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        userListener?.remove()
    }

    private func attachUserListener(for uid: String?) {
        userListener?.remove()
        guard let uid = uid else {
            self.userProfile = nil
            return
        }
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
        userListener = ref.addSnapshotListener { [weak self] snap, error in
            if let error = error {
                print("Error listening to user profile:", error)
                return
            }
            guard let snap = snap else { return }
            // Always construct an AppUser, even if some fields are missing
            let profile = AppUser(from: snap)
            DispatchQueue.main.async {
                self?.userProfile = profile
            }
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}


