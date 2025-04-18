//
//  AppUser.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/16/25.
//

import Foundation
import FirebaseFirestore

/// Represents the user's profile data stored in Firestore.
struct AppUser: Identifiable {
    let id: String
    let name: String
    let email: String
    let aura: Int
    let power: Int
    let focus: Int
    let initiative: Int
    let discipline: Int
    let stamina: Int
    let skillPoints: Int
    let agility: Agility
    let strength: Strength
    let restStartHour: Int
    let restStartMinute: Int
    let restEndHour: Int
    let restEndMinute: Int

    struct Agility {
        let speed: Int
        let balance: Int
        let flexibility: Int
    }
    struct Strength {
        let core: Int
        let lowerBody: Int
        let upperBody: Int
    }

    /// Initialize from a Firestore document snapshot, with defaults for missing or mismatched types.
    init(from snapshot: DocumentSnapshot) {
        let data = snapshot.data() ?? [:]
        self.id = snapshot.documentID
        self.name = data["name"] as? String ?? "Unknown"
        self.email = data["email"] as? String ?? ""
        self.aura = AppUser.intVal(data["aura"])
        self.power = AppUser.intVal(data["power"])
        self.focus = AppUser.intVal(data["focus"])
        self.initiative = AppUser.intVal(data["initiative"])
        self.discipline = AppUser.intVal(data["discipline"])
        self.stamina = AppUser.intVal(data["stamina"])
        self.skillPoints = {
            let val = data["skillPoints"]
            if let i = val as? Int { return i }
            if let d = val as? Double { return Int(d) }
            if let s = val as? String, let i = Int(s) { return i }
            return 0
        }()

        let ag = data["agility"] as? [String:Any] ?? [:]
        self.agility = Agility(
            speed: AppUser.intVal(ag["speed"]),
            balance: AppUser.intVal(ag["balance"]),
            flexibility: AppUser.intVal(ag["flexibility"]) )

        let st = data["strength"] as? [String:Any] ?? [:]
        self.strength = Strength(
            core: AppUser.intVal(st["core"]),
            lowerBody: AppUser.intVal(st["lowerBody"]),
            upperBody: AppUser.intVal(st["upperBody"]) )
        
        // ─── parse rest cycle or fall back to defaults ─────────────────
        if let h = data["restStartHour"] as? Int {
            self.restStartHour = h
        } else {
            self.restStartHour = 22
        }
        if let m = data["restStartMinute"] as? Int {
            self.restStartMinute = m
        } else {
            self.restStartMinute = 0
        }
        if let h2 = data["restEndHour"] as? Int {
            self.restEndHour = h2
        } else {
            self.restEndHour = 6
        }
        if let m2 = data["restEndMinute"] as? Int {
            self.restEndMinute = m2
        } else {
            self.restEndMinute = 0
        }
        
    }

    /// Helper to convert Int, Double, or String to Int, defaulting to 0.
    private static func intVal(_ val: Any?) -> Int {
        if let i = val as? Int { return i }
        if let d = val as? Double { return Int(d) }
        if let s = val as? String, let i = Int(s) { return i }
        return 0
    }
}

