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
        print("AuthVM: attaching user listener for \(uid ?? "nil")")
        userListener?.remove()
        guard let uid = uid else {
            self.userProfile = nil
            return
        }
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
        userListener = ref.addSnapshotListener { [weak self] snap, error in
            guard let snap = snap else { return }
            let profile = AppUser(from: snap)
            DispatchQueue.main.async {
                self?.userProfile = profile
            }

            // if Firestore doc didn’t already have rest‑cycle fields, write our defaults
            let raw = snap.data() ?? [:]
            if raw["restStartHour"] == nil || raw["restEndHour"] == nil {
                let uid = snap.documentID
                UserProfileService.shared.updateRestCycle(
                    startHour:   22,
                    startMinute: 0,
                    endHour:     6,
                    endMinute:   0,
                    for: uid
                ) { err in
                    if let err = err {
                        print("⚠️ failed to seed restCycle:", err)
                    }
                }
            }
        }
    }

    func signOut() throws {
        print("AuthVM: signout")
        try Auth.auth().signOut()
    }
}


