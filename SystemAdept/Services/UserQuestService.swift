//
//  UserQuestService.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserQuestService {
    private let db = Firestore.firestore()
    private var uid: String { Auth.auth().currentUser!.uid }

    /// Assigns a QuestSystem and initializes its quests.
    func assignSystem(systemId: String,
                      isUserSelected: Bool = true,
                      completion: @escaping (Result<ActiveQuestSystem, Error>) -> Void) {
        let sysRef = db.collection("questSystems").document(systemId)
        sysRef.getDocument { sysSnap, sysErr in
            if let sysErr = sysErr {
                return completion(.failure(sysErr))
            }
            let systemName = sysSnap?.data()?["name"] as? String ?? "Unknown"

            let aqsRef = self.db
                .collection("users").document(self.uid)
                .collection("activeQuestSystems")
                .document()

            let aqsData: [String: Any] = [
                "questSystemRef": sysRef,
                "questSystemName": systemName,
                "isUserSelected": isUserSelected,
                "assignedAt": Timestamp(date: Date()),
                "status": SystemAssignmentStatus.active.rawValue
            ]

            aqsRef.setData(aqsData) { error in
                if let error = error {
                    return completion(.failure(error))
                }
                self.initializeQuestProgress(systemId: systemId,
                                             aqsId: aqsRef.documentID) { initError in
                    if let initError = initError {
                        return completion(.failure(initError))
                    }
                    // Re-fetch the assigned AQS
                    aqsRef.getDocument { snap, err in
                        if let err = err {
                            return completion(.failure(err))
                        }
                        guard let snap = snap else {
                            let e = NSError(domain: "", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "No snapshot"])
                            return completion(.failure(e))
                        }
                        do {
                            let assigned = try snap.data(as: ActiveQuestSystem.self)
                            completion(.success(assigned))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    /// Refreshes an existing assignment by re-running initialization.
    func refreshProgress(for aqsId: String,
                         systemId: String,
                         completion: @escaping (Error?) -> Void) {
        initializeQuestProgress(systemId: systemId, aqsId: aqsId, completion: completion)
    }

    /// Updates the status (active/paused/stopped) of an assignment.
    func updateSystemStatus(aqsId: String,
                            status: SystemAssignmentStatus,
                            completion: ((Error?) -> Void)? = nil) {
        let aqsRef = db
            .collection("users").document(uid)
            .collection("activeQuestSystems")
            .document(aqsId)
        aqsRef.updateData(["status": status.rawValue]) { error in
            completion?(error)
        }
    }

    // MARK: - Private

    /// Initializes the questProgress sub‑collection for a new assignment.
    private func initializeQuestProgress(systemId: String,
                                         aqsId: String,
                                         completion: @escaping (Error?) -> Void) {
        let systemRef = db.collection("questSystems").document(systemId)
        let questsRef = systemRef.collection("quests")
        let userQPBase = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress")

        // Helper: convert TimeIntervalConfig to seconds
        func seconds(from cfg: TimeIntervalConfig) -> TimeInterval {
            switch cfg.unit {
            case "seconds": return cfg.amount
            case "minutes": return cfg.amount * 60
            case "hours":   return cfg.amount * 3600
            case "days":    return cfg.amount * 86400
            case "weeks":   return cfg.amount * 604800
            case "months":  return cfg.amount * 2592000
            default:        return cfg.amount
            }
        }

        // 1) Fetch system defaults
        systemRef.getDocument { sysSnap, sysErr in
            if let sysErr = sysErr {
                return completion(sysErr)
            }
            guard let sysData = sysSnap?.data() else {
                let e = NSError(domain: "", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Missing system data"])
                return completion(e)
            }
            // Default TTL: fallback to 1 day if missing
            let defaultTTC: TimeIntervalConfig = {
                if let cfg = sysData["defaultTimeToComplete"] as? [String:Any],
                   let amt = cfg["amount"] as? Double,
                   let unit = cfg["unit"] as? String {
                    return TimeIntervalConfig(amount: amt, unit: unit)
                }
                return TimeIntervalConfig(amount: 1, unit: "days")
            }()

            // 2) Fetch all quests
            questsRef.getDocuments { questSnap, questErr in
                if let questErr = questErr {
                    return completion(questErr)
                }
                let questDocs = questSnap?.documents ?? []
                let now = Date()
                let batch = self.db.batch()

                for qDoc in questDocs {
                    guard let quest = try? qDoc.data(as: Quest.self),
                          let qId = quest.id else { continue }

                    let qpRef = userQPBase.document(qId)
                    var qpData: [String: Any] = [
                        "questRef": qDoc.reference,
                        "status": "locked",
                        "failedCount": 0
                    ]

                    // Unlock rank 1 required quests
                    if quest.questRank == 1 && quest.isRequired {
                        let ttcCfg = quest.timeToCompleteOverride ?? defaultTTC
                        let duration = seconds(from: ttcCfg)
                        qpData["status"] = "available"
                        qpData["availableAt"] = Timestamp(date: now)
                        qpData["expirationTime"] = Timestamp(date: now.addingTimeInterval(duration))
                    }

                    batch.setData(qpData, forDocument: qpRef)
                }

                // 3) Commit writes
                batch.commit { batchErr in
                    completion(batchErr)
                }
            }
        }
    }
}
