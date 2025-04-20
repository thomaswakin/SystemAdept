//
//  QuestQueueViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Drives the “current quest” UI,
/// surfaces failed quests first for restart,
/// then available quests,
/// marks expired quests as failed,
/// unlocks next‑rank quests on completion,
/// and auto‑unlocks based on `availableAt` + rest cycle.
final class QuestQueueViewModel: ObservableObject {
    // MARK: - Published
    @Published var current: QuestProgress?
    @Published var questDetail: Quest?
    @Published var countdown: TimeInterval = 0
    @Published var errorMessage: String?

    // MARK: - Private
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timer: Timer?
    private var periodicTimer: Timer?
    private let activeSystem: ActiveQuestSystem

    // MARK: - Init / Deinit
    init(activeSystem: ActiveQuestSystem) {
        self.activeSystem = activeSystem
        setupListener()
        startPeriodicRefresh()
    }

    deinit {
        listener?.remove()
        timer?.invalidate()
        periodicTimer?.invalidate()
    }

    // MARK: - User Actions

    /// Manually complete the current quest.
    func completeCurrent() {
        print("completeCurrent run")
        guard
            let uid = Auth.auth().currentUser?.uid,
            let qp = current,
            let qpId = qp.id
        else { return }
        let ref = userQuestProgressRef(aqsId: activeSystem.id, qpId: qpId)
        ref.updateData([
            "status":      QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ]) { [weak self] err in
            if let e = err { self?.errorMessage = e.localizedDescription }
            self?.unlockNextRank()
            self?.fetchQuestDetailAndRefresh()
        }
    }

    /// Mark the current quest as failed (expired).
    func failCurrent() {
        print("failCurrent run")
        guard
            let uid = Auth.auth().currentUser?.uid,
            let qp = current,
            let qpId = qp.id
        else { return }
        let newCount = qp.failedCount + 1
        let ref = userQuestProgressRef(aqsId: activeSystem.id, qpId: qpId)
        ref.updateData([
            "status":      QuestProgressStatus.failed.rawValue,
            "failedCount": newCount
        ]) { err in
            if let e = err { print("❌ failCurrent error:", e) }
        }
        fetchQuestDetailAndRefresh()
    }

    /// Restart a failed quest, resetting its availableAt and expirationTime.
    func restartCurrent() {
        print("restartCurrent run")
        guard
            let qp = current,
            let qpId = qp.id,
            let quest = questDetail
        else { return }

        activeSystem.questSystemRef.getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let defaultTTC: TimeIntervalConfig
            if
                let dict = data["defaultTimeToComplete"] as? [String:Any],
                let a = dict["amount"] as? Double,
                let u = dict["unit"] as? String
            {
                defaultTTC = TimeIntervalConfig(amount: a, unit: u)
            } else {
                defaultTTC = TimeIntervalConfig(amount: 0, unit: "seconds")
            }

            let cfg = quest.timeToCompleteOverride ?? defaultTTC
            let duration: TimeInterval = {
                switch cfg.unit {
                case "minutes": return cfg.amount * 60
                case "hours":   return cfg.amount * 3600
                case "days":    return cfg.amount * 86400
                case "weeks":   return cfg.amount * 604800
                case "months":  return cfg.amount * 2592000
                default:        return cfg.amount
                }
            }()
            let now = Date()
            let exp = now.addingTimeInterval(duration)
            let ref = self.userQuestProgressRef(aqsId: self.activeSystem.id, qpId: qpId)
            print(" restartCurrent Update Data run")
            ref.updateData([
                "status":         QuestProgressStatus.available.rawValue,
                "availableAt":    Timestamp(date: now),
                "expirationTime": Timestamp(date: exp)
            ]) { err in
                if let e = err { print("❌ restartCurrent error:", e) }
            }
        }
    }

    // MARK: - Listener

    private func setupListener() {
        print("setupListener run")
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 1) Reference the user's questProgress subcollection
        let progressCollection = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(activeSystem.id)
            .collection("questProgress")

        // 2) Detach any existing listener
        listener?.remove()

        // 3) Attach a *light* closure that just forwards to processSnapshot
        listener = progressCollection.addSnapshotListener { [weak self] snap, error in
            guard let self = self else { return }
            self.processSnapshot(snap, error)
        }
    }

    /// Handles snapshot updates outside of the listener closure to simplify type-checking.
    private func processSnapshot(_ snap: QuerySnapshot?, _ error: Error?) {
        // 1) Error handling
        if let error = error {
            self.errorMessage = error.localizedDescription
            return
        }
        guard let docs = snap?.documents else { return }

        // 2) Parse all QuestProgress entries
        var progressList: [QuestProgress] = []
        for doc in docs {
            do {
                let qp = try QuestProgress.fromSnapshot(doc)
                progressList.append(qp)
            } catch {
                print("Parse error:", error)
            }
        }

        // 3) Expire any overdue quests
        self.expireOverdueQuests(progressList, systemId: self.activeSystem.id)

        // 4) Pick the next “available” quest (no .active or .pending cases exist)
        var nextQuest: QuestProgress?
        for qp in progressList {
            if qp.status == .available {
                nextQuest = qp
                break
            }
        }

        // 5) Update `current` and load details
        if let next = nextQuest {
            self.current = next
            self.fetchQuestDetail(for: next)
        } else {
            self.current = nil
        }
    }

    /// Refresh questDetail then re‑fire listener to pick up status changes.
    private func fetchQuestDetailAndRefresh() {
        print("fetchQuestDetailAndRefresh run")
        if let qp = current {
            fetchQuestDetail(for: qp)
        }
        setupListener()
    }

    private func fetchQuestDetail(for qp: QuestProgress) {
        print("fetchQuestDetail run")
        qp.questRef.getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let e = err {
                self.errorMessage = e.localizedDescription
                return
            }
            guard
                let data = snap?.data(),
                let q = Quest(from: data, id: snap!.documentID)
            else {
                self.errorMessage = "Malformed quest data"
                return
            }
            self.questDetail = q
        }
    }
    // MARK: - Countdown

    private func startTimer(until end: Date) {
        print("startTimer run")
        
        // 1) Invalidate any existing timer and seed the initial countdown
        timer?.invalidate()
        let initialRemaining = end.timeIntervalSinceNow
        countdown = max(0, initialRemaining)
        
        // 2) Pull out the interval and repeats into their own variables
        let interval: TimeInterval = 1
        let shouldRepeat: Bool = true
        
        // 3) Define the block separately, capturing `end` and `self`
        let callback: (Timer) -> Void = { [weak self] t in
            guard let self = self else { return }
            
            // Break up the math into two steps
            let remaining = end.timeIntervalSinceNow
            let clamped   = max(0, remaining)
            self.countdown = clamped
            
            if clamped <= 0 {
                t.invalidate()
                self.failCurrent()
            }
        }
        
        // 4) Schedule the timer with our smaller pieces
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: shouldRepeat,
            block: callback
        )
    }

    private func stopTimer() {
        print("stopTimer run")
        timer?.invalidate()
        timer = nil
        countdown = 0
    }

    // MARK: - Periodic Refresh

    /// Flip any locked quests whose `availableAt` ≤ now → available, then unlock next rank.
    func refreshAvailableQuests() {
        print("refreshAvailableQuests run")
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let now = Date()
        let col = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(activeSystem.id)
            .collection("questProgress")

        col
            .whereField("status", isEqualTo: QuestProgressStatus.locked.rawValue)
            .whereField("availableAt", isLessThanOrEqualTo: Timestamp(date: now))
            .getDocuments { [weak self] snap, err in
                guard let self = self, err == nil else { return }
                let batch = self.db.batch()
                snap?.documents.forEach { doc in
                    batch.updateData(
                        ["status": QuestProgressStatus.available.rawValue],
                        forDocument: doc.reference
                    )
                }
                batch.commit { _ in
                    self.unlockNextRank()
                }
            }
    }

    private func startPeriodicRefresh() {
        print("startPeriodicRefresh run")
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(
            withTimeInterval: 30, repeats: true
        ) { [weak self] _ in
            self?.refreshAvailableQuests()
        }
    }

    // MARK: - Rest & Progression

    private func adjustedDateConsideringRest(
        _ baseDate: Date,
        restStartHour: Int, restStartMinute: Int,
        restEndHour: Int, restEndMinute: Int
    ) -> Date {
        print("adjustDateConsideringRest run")
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: baseDate)
        guard let hour = comps.hour, let minute = comps.minute else { return baseDate }
        let overnight = restStartHour >= restEndHour
        let inRest: Bool = {
            if overnight {
                let beforeMid = (hour > restStartHour || (hour == restStartHour && minute >= restStartMinute))
                let afterMid = (hour < restEndHour || (hour == restEndHour && minute < restEndMinute))
                return beforeMid || afterMid
            } else {
                return (hour > restStartHour || (hour == restStartHour && minute >= restStartMinute)) &&
                       (hour < restEndHour   || (hour == restEndHour   && minute < restEndMinute))
            }
        }()
        guard inRest else { return baseDate }

        var endComps = cal.dateComponents([.year, .month, .day], from: baseDate)
        endComps.hour = restEndHour
        endComps.minute = restEndMinute

        if overnight {
            if let d = cal.date(from: endComps) {
                // Pre‑midnight rest → ends next day
                if hour > restStartHour || (hour == restStartHour && minute >= restStartMinute) {
                    return cal.date(byAdding: .day, value: 1, to: d) ?? d
                }
                return d
            }
        } else if let d = cal.date(from: endComps) {
            return d
        }

        return baseDate
    }

    private func unlockNextRank() {
        print("unlockNextRank run")
        let uid   = Auth.auth().currentUser!.uid
        let aqsId = activeSystem.id
        let sysId = activeSystem.questSystemRef.documentID

        fetchSystemDocument(sysId: sysId, uid: uid, aqsId: aqsId)
    }
    
    private func fetchSystemDocument(sysId: String, uid: String, aqsId: String) {
        let sysRef = db.collection("questSystems").document(sysId)
        sysRef.getDocument { [weak self] snap, err in
            guard let self = self,
                  let data = snap?.data(),
                  err == nil
            else { return }

            // compute defaultTTC here
            let defaultTTC: TimeIntervalConfig
            if let dict = data["defaultTimeToComplete"] as? [String:Any],
               let a = dict["amount"] as? Double,
               let u = dict["unit"]   as? String {
                defaultTTC = TimeIntervalConfig(amount: a, unit: u)
            } else {
                defaultTTC = TimeIntervalConfig(amount: 0, unit: "seconds")
            }

            self.fetchAllProgress(
              uid:            uid,
              aqsId:          aqsId,
              defaultTTC:     defaultTTC
            )
        }
    }
    
    private func fetchAllProgress(
        uid: String,
        aqsId: String,
        defaultTTC: TimeIntervalConfig
    ) {
        let col = db
          .collection("users").document(uid)
          .collection("activeQuestSystems").document(aqsId)
          .collection("questProgress")

        col.getDocuments { [weak self] snap, err in
            guard let self = self,
                  err == nil,
                  let docs = snap?.documents
            else { return }

            var byRank = [Int: [(QuestProgress, Quest)]]()
            let group = DispatchGroup()

            for doc in docs {
                // parse QuestProgress
                guard let qp = try? doc.data(as: QuestProgress.self) else { continue }
                group.enter()
                qp.questRef.getDocument { qsnap, _ in
                    defer { group.leave() }
                    guard let qsnap = qsnap,
                          let qdata = qsnap.data(),
                          let q     = Quest(from: qdata, id: qsnap.documentID)
                    else { return }
                    byRank[q.questRank, default: []].append((qp, q))
                }
            }

            group.notify(queue: .main) {
                self.processByRank(
                  byRank:    byRank,
                  defaultTTC: defaultTTC,
                  uid:        uid,
                  aqsId:      aqsId
                )
            }
        }
    }
    
    private func processByRank(
      byRank:    [Int: [(QuestProgress, Quest)]],
      defaultTTC: TimeIntervalConfig,
      uid:        String,
      aqsId:      String
    ) {
        // sorted ranks
        let ranks = byRank.keys.sorted()
        guard let rank = ranks.first(where: { rank in
            let required = byRank[rank]!.filter { $0.1.isRequired }
            return required.allSatisfy { $0.0.status == .completed }
        }) else { return }

        let nextLocked = (byRank[rank + 1] ?? []).filter { $0.0.status == .locked }
        guard !nextLocked.isEmpty else { return }

        // compute the availability time based on rest
        let latest = byRank[rank]!.compactMap { $0.0.expirationTime }.max() ?? Date()
        UserProfileService.shared.fetchUserProfile(for: uid) { profile, _ in
            let rsH = profile?.restStartHour   ?? 22
            let rsM = profile?.restStartMinute ??  0
            let reH = profile?.restEndHour     ??   6
            let reM = profile?.restEndMinute   ??   0
            let avail = self.adjustedDateConsideringRest(
              latest,
              restStartHour:   rsH, restStartMinute: rsM,
              restEndHour:     reH, restEndMinute:   reM
            )

            let batch = self.db.batch()
            for (qp, q) in nextLocked {
                // compute duration exactly as before…
                let dur: TimeInterval = {
                    let cfg = q.timeToCompleteOverride ?? defaultTTC
                    switch cfg.unit {
                    case "minutes": return cfg.amount * 60
                    case "hours":   return cfg.amount * 3600
                    case "days":    return cfg.amount * 86400
                    case "weeks":   return cfg.amount * 604800
                    case "months":  return cfg.amount * 2592000
                    default:        return cfg.amount
                    }
                }()

                let ref = self.userQuestProgressRef(aqsId: aqsId, qpId: qp.id!)
                batch.updateData([
                    "status":         QuestProgressStatus.available.rawValue,
                    "availableAt":    Timestamp(date: avail),
                    "expirationTime": Timestamp(date: avail.addingTimeInterval(dur))
                ], forDocument: ref)
            }
            batch.commit()
        }
    }
    
    

    // MARK: - Helpers

    private func userQuestProgressRef(
        aqsId: String, qpId: String
    ) -> DocumentReference {
        let uid = Auth.auth().currentUser!.uid
        return db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress").document(qpId)
    }
}
