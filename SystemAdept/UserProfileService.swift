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
                completion(nil, NSError(domain: "No data", code: 0, userInfo: nil))
            }
        }
    }
}