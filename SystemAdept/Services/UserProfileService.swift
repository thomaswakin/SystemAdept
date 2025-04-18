//
//  UserProfileService.swift
//  SystemAdept
//
//  Created by Thomas Akin on 3/30/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class UserProfileService {
    static let shared = UserProfileService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Updates just the rest‑cycle fields in the user’s profile document.
    func updateRestCycle(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        for uid: String,
        completion: @escaping (Error?) -> Void
    ) {
        let data: [String: Any] = [
            "restStartHour":   startHour,
            "restStartMinute": startMinute,
            "restEndHour":     endHour,
            "restEndMinute":   endMinute
        ]
        db.collection("users")
          .document(uid)
          .updateData(data, completion: completion)
    }
    
    // Save a new user profile (for a new user)
    func createUserProfile(for user: UserProfile, completion: @escaping (Error?) -> Void) {
        do {
            let data = try user.asDictionary()
            db.collection("users").document(user.id).setData(data, merge: true, completion: completion)
        } catch {
            completion(error)
        }
    }
    
    // Update the user's name in their profile
    func updateUserProfile(name: String, for uid: String, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(uid).updateData([
            "name": name
        ], completion: completion)
    }
    
    // Fetch the user profile for a given UID
    func fetchUserProfile(for uid: String, completion: @escaping (UserProfile?, Error?) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                completion(nil, error)
                return
            }
            if let data = document?.data() {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                    let profile = try JSONDecoder().decode(UserProfile.self, from: jsonData)
                    completion(profile, nil)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, nil)
            }
        }
    }
    
    // Ensure a user profile exists; if not, create a default one.
    func ensureUserProfile(for uid: String, email: String, completion: @escaping (UserProfile?, Error?) -> Void) {
        fetchUserProfile(for: uid) { profile, error in
            if let error = error {
                completion(nil, error)
                return
            }
            if let profile = profile {
                // Profile already exists.
                completion(profile, nil)
            } else {
                // No profile exists, so create a default profile.
                let defaultName = email.components(separatedBy: "@").first ?? email
                let defaultProfile = UserProfile(
                    id: uid,
                    email: email,
                    name: defaultName,
                    aura: 0,
                    skillPoints: "--",
                    strength: StrengthMetrics(upperBody: 0, core: 0, lowerBody: 0),
                    agility: AgilityMetrics(flexibility: 0, speed: 0, balance: 0),
                    stamina: 0,
                    power: 0,
                    focus: 0,
                    discipline: 0,
                    initiative: 0
                )
                self.createUserProfile(for: defaultProfile) { error in
                    if let error = error {
                        completion(nil, error)
                    } else {
                        completion(defaultProfile, nil)
                    }
                }
            }
        }
    }
}
