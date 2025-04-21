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
/// unlocks next‑rank quests on completion (with optional acceleration),
/// and auto‑unlocks based on `availableAt` + rest cycle.
final class QuestQueueViewModel: ObservableObject {
    // MARK: - Published
    @Published var current: QuestProgress?
    @Published var questDetail: Quest?
    @Published var countdown: TimeInterval = 0
    @Published var errorMessage: String?
    
    // Prompt state for accelerating to next rank
    @Published var showAcceleratePrompt: Bool = false
    @Published var pendingNextRankQuestIDs: [String] = []
    
    // Store latest expiration among the just‑completed rank
    private var latestExpirationForRank: Date?
    
    // MARK: - Private
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timer: Timer?
    private var periodicTimer: Timer?
    private let activeSystem: ActiveQuestSystem
    
    /// Keep the most recent quest progress list for periodic unlocking
    private var lastProgressList: [QuestProgress] = []
    
    /// Cache Quest ID → Quest for quick lookups
    private var questCache: [String: Quest] = [:]

    // MARK: - Init / Deinit
    init(activeSystem: ActiveQuestSystem) {
        self.activeSystem = activeSystem
        
        // Preload all quest definitions into the cache
        self.preloadAllQuests()
        
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
        print("QuestQueueVM: completeCurrent run")
        guard
            let uid   = Auth.auth().currentUser?.uid,
            let qp    = current,
            let qpId  = qp.id
        else { return }

        let ref = userQuestProgressRef(aqsId: activeSystem.id, qpId: qpId)
        ref.updateData([
            "status":      QuestProgressStatus.completed.rawValue,
            "completedAt": Timestamp(date: Date())
        ]) { [weak self] err in
            if let e = err {
                self?.errorMessage = e.localizedDescription
                return
            }
            // **New**: Prepare next‑rank quests and show prompt if eligible
            self?.prepareNextRankQuests(afterCompleting: qp)
        }
    }

    /// Mark the current quest as failed (expired).
    func failCurrent() {
        print("QuestQueueVM: failCurrent run")
        guard
            let uid   = Auth.auth().currentUser?.uid,
            let qp    = current,
            let qpId  = qp.id
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

    /// Restart a failed quest by setting its availability and expiration using the rank‑based duration.
    func restartCurrent() {
        print("QuestQueueVM: restartCurrent run")
        guard let qp = current, let qpId = qp.id, let quest = questDetail else { return }

        activeSystem.questSystemRef.getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let defaultTTC: TimeIntervalConfig
            if
                let dict = data["defaultTimeToComplete"] as? [String:Any],
                let a    = dict["amount"] as? Double,
                let u    = dict["unit"]   as? String
            {
                defaultTTC = TimeIntervalConfig(amount: a, unit: u)
            } else {
                print("⚠️ Warning: defaultTimeToComplete missing; using 1h fallback")
                defaultTTC = TimeIntervalConfig(amount: 1, unit: "hours")
            }

            // Combine override + default and log
            let cfg = quest.timeToCompleteOverride ?? defaultTTC
            print("  restartCurrent: override=\(String(describing: quest.timeToCompleteOverride)), using defaultTTC=\(defaultTTC)")

            // Compute seconds
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
            
            print("  Settings - now: \(now), exp: \(exp), status \(QuestProgressStatus.available.rawValue)")
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
        print("QuestQueueVM: setupListener run")
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let progressCollection = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(activeSystem.id)
            .collection("questProgress")

        listener?.remove()
        listener = progressCollection.addSnapshotListener { [weak self] snap, error in
            guard let self = self else { return }
            self.processSnapshot(snap, error)
        }
    }

    /// Handles snapshot updates outside of the listener closure to simplify type‑checking.
    private func processSnapshot(_ snap: QuerySnapshot?, _ error: Error?) {
        // 1) Error handling
        print("QuestQueueVM: processSnapshot run")
        if let error = error {
            self.errorMessage = error.localizedDescription
            return
        }
        guard let docs = snap?.documents else { return }

        // 2) Parse all QuestProgress entries
        var progressList: [QuestProgress] = []
        for doc in docs {
            if let qp = try? QuestProgress.fromSnapshot(doc) {
                progressList.append(qp)
            }
        }

        // 3) Expire any overdue quests
        expireOverdueQuests(progressList, systemId: activeSystem.id)

        // 4) Activate any now‑available quests
        for qp in progressList {
            if let avail = qp.availableAt, avail <= Date(), qp.status == .locked {
                let ref = userQuestProgressRef(aqsId: activeSystem.id, qpId: qp.id!)
                ref.updateData(["status": QuestProgressStatus.available.rawValue])
            }
        }

        // 5) Store for periodic review
        lastProgressList = progressList

        // 6) Update current quest display
        if let next = progressList.first(where: { $0.status == .available }) {
            current = next
            fetchQuestDetail(for: next)
        } else {
            current = nil
        }
    }

    /// Refresh questDetail then re‑fire listener to pick up status changes.
    private func fetchQuestDetailAndRefresh() {
        print("QuestQueueVM: fetchQuestDetailAndRefresh run")
        if let qp = current {
            fetchQuestDetail(for: qp)
        }
        setupListener()
    }

    private func fetchQuestDetail(for qp: QuestProgress) {
        print("QuestQueueVM: fetchQuestDetail run")
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
        print("QuestQueueVM: startTimer run")
        timer?.invalidate()
        countdown = max(0, end.timeIntervalSinceNow)

        let interval: TimeInterval = 1
        let shouldRepeat = true
        let callback: (Timer) -> Void = { [weak self] t in
            guard let self = self else { return }
            let remaining = end.timeIntervalSinceNow
            let clamped   = max(0, remaining)
            self.countdown = clamped
            if clamped <= 0 {
                t.invalidate()
                self.failCurrent()
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: shouldRepeat, block: callback)
    }

    private func stopTimer() {
        print("QuestQueueVM: stopTimer run")
        timer?.invalidate()
        timer = nil
        countdown = 0
    }

    // MARK: - Periodic Refresh

    /// Flip any locked quests whose `availableAt` ≤ now → available, then unlock next rank automatically.
    private func startPeriodicRefresh() {
        print("QuestQueueVM: startPeriodicRefresh run")
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 1) Refresh expirations & availability
            self.processSnapshot(nil, nil)
            // 2) Auto‑unlock next rank if a full rank is complete
            self.periodicUnlockNextRank()
        }
    }
    
    // MARK: - New Loading Logic

    /// Preload and cache all Quest definitions for this ActiveQuestSystem.
    private func preloadAllQuests() {
        print("QuestQueueVM: preloadAllQuests run")
        let sysId = activeSystem.questSystemRef.documentID
        db.collection("questSystems").document(sysId)
          .collection("quests")
          .getDocuments { [weak self] snap, error in
            guard let self = self, let docs = snap?.documents else { return }
            
            for doc in docs {
                // Use the failable initializer directly, avoiding ‘do/try’
                if let q = Quest(from: doc.data(), id: doc.documentID) {
                    // Store in cache using a plain String key
                    let key = q.id
                    self.questCache.updateValue(q, forKey: key)
                } else {
                    print("Quest cache error: failed to parse Quest for doc \(doc.documentID)")
                }
            }
          }
    }

    // MARK: - New Next‑Rank Logic

    /// Called after marking a quest completed: prepare and prompt to unlock next rank.
    private func prepareNextRankQuests(afterCompleting qp: QuestProgress) {
        print("QuestQueueVM: preparedNextRankQuests run")
        let uid   = Auth.auth().currentUser!.uid
        let aqsId = activeSystem.id

        db.collection("users").document(uid)
          .collection("activeQuestSystems").document(aqsId)
          .collection("questProgress")
          .getDocuments { [weak self] snap, _ in
            guard let self = self, let docs = snap?.documents else { return }

            // 1) parse all progresses
            let progresses = docs.compactMap { try? QuestProgress.fromSnapshot($0) }

            // 2) determine this quest's rank
            let thisRank = self.rank(of: qp)

            // 3) collect all in same rank & check completion
            let sameRank = progresses.filter { self.rank(of: $0) == thisRank }
            guard sameRank.allSatisfy({ $0.status == .completed }) else {
                self.fetchQuestDetailAndRefresh()
                return
            }

            // 4) record latest expiration
            self.latestExpirationForRank = sameRank
              .compactMap { $0.expirationTime }
              .max() ?? Date()

            // 5) identify next-rank quest IDs
            let nextRank = thisRank + 1
            self.pendingNextRankQuestIDs = progresses
              .filter { self.rank(of: $0) == nextRank }
              .compactMap { $0.id }

            // 6) show accelerate prompt
            self.showAcceleratePrompt = true
        }
    }

    /// Called by your UI when the user taps “Yes” or “No” on the accelerate prompt.
    func applyAccelerationChoice(_ accelerate: Bool) {
        print("QuestQueueVM: applyAccelerationChoice: \(accelerate)")
        guard !pendingNextRankQuestIDs.isEmpty else { return }
        let uid    = Auth.auth().currentUser!.uid
        let aqsId  = activeSystem.id
        let now    = Date()
        let base   = accelerate ? now : (latestExpirationForRank ?? now)

        // respect rest cycle
        // you’ll need these from profile or defaults:
        let rsH = /* restStartHour from profile */ 22
        let rsM = /* restStartMinute */ 0
        let reH = /* restEndHour */ 6
        let reM = /* restEndMinute */ 0

        let availDate = self.adjustedDateConsideringRest(
          base,
          restStartHour:   rsH, restStartMinute: rsM,
          restEndHour:     reH, restEndMinute:   reM
        )

        // compute duration for next rank
        let nextRank = (questDetail?.questRank ?? 0) + 1
        let duration = defaultDuration(forRank: nextRank)

        // batch update availableAt + expirationTime
        let batch = db.batch()
        for qpId in pendingNextRankQuestIDs {
            let ref = userQuestProgressRef(aqsId: aqsId, qpId: qpId)
            batch.updateData([
                "availableAt":    Timestamp(date: availDate),
                "expirationTime": Timestamp(date: availDate.addingTimeInterval(duration))
            ], forDocument: ref)
        }
        batch.commit { [weak self] err in
            if let e = err { print("batch unlock error:", e) }
            // re‑run listener logic immediately
            self?.processSnapshot(nil, nil)
        }

        // tidy up
        showAcceleratePrompt = false
        pendingNextRankQuestIDs = []
    }
    
    /// Look up the questRank for a given QuestProgress.
    private func rank(of qp: QuestProgress) -> Int {
        print("QuestQueueVM: rank(of: \(qp))")
        guard let questId = qp.id,
              let q = questCache[questId]
        else { return 0 }
        return q.questRank
    }

    /// Determine a TimeInterval to use for expiration for any quest of that rank.
    private func defaultDuration(forRank rank: Int) -> TimeInterval {
        print("QuestQueueVM: defaultDuration(forRank: \(rank))")
        if let q = questCache.values.first(where: { $0.questRank == rank }) {
            let cfg = q.timeToCompleteOverride ?? TimeIntervalConfig(amount: 0, unit: "seconds")
            switch cfg.unit {
            case "minutes": return cfg.amount * 60
            case "hours":   return cfg.amount * 3600
            case "days":    return cfg.amount * 86400
            case "weeks":   return cfg.amount * 604800
            case "months":  return cfg.amount * 2592000
            default:        return cfg.amount
            }
        }
        return 3600
    }
    
    /// Adjusts a base date to skip over the user’s rest cycle.
    private func adjustedDateConsideringRest(
        _ baseDate: Date,
        restStartHour: Int, restStartMinute: Int,
        restEndHour: Int, restEndMinute: Int
    ) -> Date {
        print("QuestQueueVM: adjustedDateConsideringRest: \(baseDate), restStartHour: \(restStartHour), restStartMinute: \(restStartMinute), restEndHour: \(restEndHour), restEndMinute: \(restEndMinute)")
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: baseDate)
        guard let hour = comps.hour, let minute = comps.minute else { return baseDate }
        let overnight = restStartHour >= restEndHour

        // Determine if baseDate falls within rest
        let inRest: Bool = {
            if overnight {
                let beforeMid = (hour > restStartHour || (hour == restStartHour && minute >= restStartMinute))
                let afterMid  = (hour < restEndHour   || (hour == restEndHour   && minute <  restEndMinute))
                return beforeMid || afterMid
            } else {
                return (hour > restStartHour || (hour == restStartHour && minute >= restStartMinute))
                    && (hour < restEndHour   || (hour == restEndHour   && minute <  restEndMinute))
            }
        }()
        // If not in rest, return the original date
        guard inRest else { return baseDate }

        // Build a date representing the end of rest on that day
        var endComps = cal.dateComponents([.year, .month, .day], from: baseDate)
        endComps.hour   = restEndHour
        endComps.minute = restEndMinute

        // Handle overnight rest spanning midnight
        if overnight, let d = cal.date(from: endComps) {
            // If we’re in the “after midnight” portion, move to the next day
            if hour > restStartHour || (hour == restStartHour && minute >= restStartMinute) {
                return cal.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        }

        // Normal same-day rest end
        if let d = cal.date(from: endComps) {
            return d
        }

        return baseDate
    }
    
    // MARK: - Helpers

    /// Returns the Firestore document reference for a given user’s questProgress entry.
    private func userQuestProgressRef(
        aqsId: String,
        qpId:  String
    ) -> DocumentReference {
        print("QuestQueueVM: userQuestProgressRef: \(aqsId), \(qpId)")
        let uid = Auth.auth().currentUser!.uid
        return db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aqsId)
            .collection("questProgress").document(qpId)
    }
    
    /// Flip any locked quests whose `availableAt` ≤ now → available, then fire off maintenance.
    func refreshAvailableQuests() {
        print("QuestQueueVM: refreshAvailableQuests")
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let now = Date()
        let col = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(activeSystem.id)
            .collection("questProgress")

        // 1) Find all locked quests whose availableAt has arrived
        col
          .whereField("status", isEqualTo: QuestProgressStatus.locked.rawValue)
          .whereField("availableAt", isLessThanOrEqualTo: Timestamp(date: now))
          .getDocuments { [weak self] snap, err in
            guard let self = self, err == nil else { return }
            let batch = self.db.batch()

            // 2) Flip them to available
            snap?.documents.forEach { doc in
                batch.updateData(
                  ["status": QuestProgressStatus.available.rawValue],
                  forDocument: doc.reference
                )
            }

            // 3) Commit the batch, then re-run our snapshot + unlock logic
            batch.commit { _ in
                // This will trigger your listener to pick up the new statuses,
                // but to be sure we re-evaluate right away we can also:
                self.processSnapshot(nil, nil)
                self.periodicUnlockNextRank()
            }
        }
    }
    
    /// Automatically unlock the next quest rank (no prompt), run on a timer.
    private func periodicUnlockNextRank() {
        print("QuestQueueVM: periodicUnlockNextRank")
        // 1) Find highest fully‑completed rank
        let completed = lastProgressList.filter { $0.status == .completed }
        let highestRank = completed.map { rank(of: $0) }.max() ?? -1
        guard highestRank >= 0 else { return }

        // 2) Identify locked quests in the next rank
        let nextRank = highestRank + 1
        let lockedNext = lastProgressList.filter {
            rank(of: $0) == nextRank && $0.status == .locked
        }
        guard !lockedNext.isEmpty else { return }

        // 3) Base time = latest expiration in completed rank
        let prevGroup = lastProgressList.filter { rank(of: $0) == highestRank }
        let latestExp = prevGroup.compactMap { $0.expirationTime }.max() ?? Date()

        // 4) Respect rest cycles
        let uid = Auth.auth().currentUser!.uid
        UserProfileService.shared.fetchUserProfile(for: uid) { profile, _ in
            let rsH = profile?.restStartHour   ?? 22
            let rsM = profile?.restStartMinute ??  0
            let reH = profile?.restEndHour     ??   6
            let reM = profile?.restEndMinute   ??   0

            let avail = self.adjustedDateConsideringRest(
                latestExp,
                restStartHour:   rsH, restStartMinute: rsM,
                restEndHour:     reH, restEndMinute:   reM
            )

            // 5) Compute duration for next rank
            let duration = self.defaultDuration(forRank: nextRank)

            // 6) Batch‑unlock all those quests
            let aqsId = self.activeSystem.id
            let batch = self.db.batch()
            for qp in lockedNext {
                guard let qpId = qp.id else { continue }
                let ref = self.userQuestProgressRef(aqsId: aqsId, qpId: qpId)
                batch.updateData([
                    "availableAt":    Timestamp(date: avail),
                    "expirationTime": Timestamp(date: avail.addingTimeInterval(duration))
                ], forDocument: ref)
            }
            batch.commit()
        }
    }
    
}


// MARK: - Maintenance Helper

extension QuestQueueViewModel {
    /// Run expiration, activation, and unlock logic for a given system without UI.
    static func runMaintenance(for system: ActiveQuestSystem) {
        print("QuestQueueVM: running maintenance for \(system)")
        let vm = QuestQueueViewModel(activeSystem: system)
        // 1) Expire overdue & activate any quests whose availableAt ≤ now
        vm.refreshAvailableQuests()
        // 2) Auto-unlock next rank without prompting
        vm.periodicUnlockNextRank()
    }
}

// MARK: –– Static Action Helpers

extension QuestQueueViewModel {
    /// Completes the given ActiveQuest inside its system.
    static func complete(_ aq: ActiveQuest, in system: ActiveQuestSystem) {
        print("QuestQueueVM: completing \(aq) in \(system)")
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let qpRef = Firestore.firestore()
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(aq.aqsId)
            .collection("questProgress").document(aq.id)

        // Aura gain logic
        let failed     = Double(aq.progress.failedCount)
        let debuff     = aq.quest.questRepeatDebuffOverride ?? 1.0
        let multiplier = pow(debuff, failed)
        let auraGain   = aq.quest.questAuraGranted * multiplier

        let batch = Firestore.firestore().batch()
        batch.updateData([
            "status":      QuestProgressStatus.completed.rawValue,
            "completedAt": FieldValue.serverTimestamp()
        ], forDocument: qpRef)
        batch.updateData([
            "aura": FieldValue.increment(auraGain)
        ], forDocument: Firestore.firestore().collection("users").document(uid))
        batch.commit()

        // run maintenance on the real system
        runMaintenance(for: system)
    }

    /// Restarts the given ActiveQuest inside its system by delegating to the instance method.
    static func restart(_ aq: ActiveQuest, in system: ActiveQuestSystem) {
        print("QuestQueueVM: restart \(aq)")
        // 1) Create a QuestQueueViewModel for that system
        let vm = QuestQueueViewModel(activeSystem: system)

        // 2) Seed the current questProgress and detail so restartCurrent() has context
        vm.current = aq.progress
        vm.questDetail = aq.quest

        // 3) Invoke the existing instance method, which uses the override‑based duration logic
        vm.restartCurrent()
    }

}
