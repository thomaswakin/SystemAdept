//
//  UserQuestService.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Computes when the next quests should become available, given:
/// - lastExpiration: the Date the last quest expired or completed
/// - restCycle: user’s rest window
private func calculateNextStart(
    after lastExpiration: Date,
    restCycle: AppUser.RestCycle,
    calendar: Calendar = .current
) -> Date {
    let dayStart = calendar.startOfDay(for: lastExpiration)
    let restStartBase = calendar.date(
        byAdding: .hour, value: restCycle.startHour,
        to: dayStart
    )!.addingTimeInterval(TimeInterval(restCycle.startMinute * 60))

    let restEndBase = calendar.date(
        byAdding: .hour, value: restCycle.endHour,
        to: dayStart
    )!.addingTimeInterval(TimeInterval(restCycle.endMinute * 60))

    // Handle overnight rest window
    let restEnd = restEndBase < restStartBase
        ? calendar.date(byAdding: .day, value: 1, to: restEndBase)!
        : restEndBase

    // If within rest window, defer to end of rest
    if lastExpiration >= restStartBase && lastExpiration < restEnd {
        return restEnd
    }
    // Otherwise, unlock immediately
    return lastExpiration
}

final class UserQuestService {
    static let shared = UserQuestService()
    private let db = Firestore.firestore()
    private init() {}

    /// Marks a quest completed, grants aura (with debuff), then unlocks next rank.
    func completeQuest(
        aqsId: String,
        progress: QuestProgress,
        quest: Quest,
        system: QuestSystem,
        user: AppUser
    ) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let qpRef = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress").document(progress.id!)

        // Compute debuffed aura gain
        let failedCount = Double(progress.failedCount)
        let debuffFactor = quest.questRepeatDebuffOverride ?? 1.0
        let multiplier = pow(debuffFactor, failedCount)
        let auraGain = quest.questAuraGranted * multiplier

        let userRef = db.collection("users").document(uid)

        let batch = db.batch()
        // 1) mark quest completed
        batch.updateData([
            "status": QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ], forDocument: qpRef)

        // 2) increment user aura
        batch.updateData([
            "aura": FieldValue.increment(auraGain)
        ], forDocument: userRef)

        batch.commit { [weak self] err in
            if let err = err {
                print("Error completing quest:", err)
                return
            }
            self?.computeAndUnlockNextRank(
                aqsId: aqsId,
                system: system,
                user: user
            )
        }
    }

    /// After finishing a rank, schedules the next rank’s quests for availability.
    private func computeAndUnlockNextRank(
        aqsId: String,
        system: QuestSystem,
        user: AppUser
    ) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let qpColl = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress")

        qpColl.getDocuments(source: .default) { [weak self] snap, err in
            guard let self = self,
                  let docs = snap?.documents,
                  err == nil else {
                print("Error fetching questProgress:", err ?? "unknown")
                return
            }

            // Parse progress items with raw rank and expiration
            struct Prog { let progress: QuestProgress; let rank: Int; let expiration: Date }
            var items: [Prog] = []
            for docSnap in docs {
                let data = docSnap.data()
                // Decode QuestProgress
                guard let qp = try? docSnap.data(as: QuestProgress.self) else { continue }
                // Parse rank from raw data
                let rankVal: Int = {
                    if let i = data["questRank"] as? Int { return i }
                    if let s = data["questRank"] as? String, let i = Int(s) { return i }
                    return 0
                }()
                // Parse expiration timestamp
                guard let ts = data["expirationTime"] as? Timestamp else { continue }
                let expDate = ts.dateValue()
                items.append(Prog(progress: qp, rank: rankVal, expiration: expDate))
            }

            // Group by rank
            let grouped = Dictionary(grouping: items, by: { $0.rank })
            let sortedRanks = grouped.keys.sorted()

            // Find max fully-completed rank
            var completedMaxRank: Int? = nil
            for rank in sortedRanks {
                let group = grouped[rank]!
                if group.allSatisfy({ $0.progress.status == .completed }) {
                    completedMaxRank = rank
                }
            }
            guard let lastRank = completedMaxRank else { return }
            let nextRank = lastRank + 1

            // Early exit if no next-rank quests
            guard let nextQuests = system.questsByRank[nextRank], !nextQuests.isEmpty else {
                return
            }

            // Compute latest expiration in lastRank
            let lastExp = grouped[lastRank]!
                .map({ $0.expiration })
                .max() ?? Date()

            // Calculate next start respecting rest cycle
            let nextStart = calculateNextStart(
                after: lastExp,
                restCycle: user.restCycle
            )

            // Prepare Firestore references
            let systemDocRef = db
                .collection("questSystems").document(system.id)
            let questDefsColl = systemDocRef.collection("quests")

            // Batch-unlock next rank quests
            let batch = db.batch()
            for questDef in nextQuests {
                let newDocID = "\(questDef.questName)_\(nextRank)"
                let newQPRef = qpColl.document(newDocID)

                // Duration = override or default
                let duration = questDef.timeToCompleteOverride
                    ?? system.defaultTimeToComplete
                let expDate = nextStart.addingTimeInterval(duration)

                let questDocRef = questDefsColl.document(questDef.id)
                let dataMap: [String: Any] = [
                    "questRef": questDocRef,
                    "questRank": nextRank,
                    "status": QuestProgressStatus.available.rawValue,
                    "availableAt": Timestamp(date: nextStart),
                    "expirationTime": Timestamp(date: expDate),
                    "failedCount": 0
                ]
                batch.setData(dataMap, forDocument: newQPRef)
            }
            batch.commit { err in
                if let err = err {
                    print("Error unlocking next rank:", err)
                }
            }
        }
    }
}

