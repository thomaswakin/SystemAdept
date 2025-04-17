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
            print("🔑 Auth state changed, user:", user?.uid ?? "nil")
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
            print("👤 No UID, clearing userProfile")
            DispatchQueue.main.async { self.userProfile = nil }
            return
        }

        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)

        // On first fetch, ensure restCycle fields exist
        ref.getDocument { snap, error in
            if let error = error {
                print("⚠️ Initial get error:", error)
                return
            }
            guard let snap = snap else { return }
            let data = snap.data() ?? [:]
            if data["restCycleStartHour"] == nil {
                print("🛌 Setting default rest cycle")
                ref.setData([
                    "restCycleStartHour": 22,
                    "restCycleStartMinute": 0,
                    "restCycleEndHour": 6,
                    "restCycleEndMinute": 0
                ], merge: true)
            }
        }

        // Real‑time listener
        userListener = ref.addSnapshotListener { [weak self] snap, error in
            if let error = error {
                print("⚠️ SnapshotListener error:", error)
                return
            }
            guard let snap = snap else { return }
            let profile = AppUser(from: snap)
            DispatchQueue.main.async {
                self?.userProfile = profile
            }
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Updates the user's rest cycle.
    func setRestCycle(startHour: Int, startMinute: Int,
                      endHour: Int, endMinute: Int) {
        guard let uid = firebaseUser?.uid else { return }
        let userRef = Firestore.firestore()
            .collection("users").document(uid)
        userRef.setData([
            "restCycleStartHour": startHour,
            "restCycleStartMinute": startMinute,
            "restCycleEndHour": endHour,
            "restCycleEndMinute": endMinute
        ], merge: true)
    }
}


