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
            let qp  = current,
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
            let qp  = current,
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
            let qp   = current,
            let qpId = qp.id,
            let quest = questDetail
        else { return }

        activeSystem.questSystemRef.getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let defaultTTC: TimeIntervalConfig
            if
                let dict = data["defaultTimeToComplete"] as? [String:Any],
                let a    = dict["amount"] as? Double,
                let u    = dict["unit"] as? String
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
        let col = db
            .collection("users").document(uid)
            .collection("activeQuestSystems").document(activeSystem.id)
            .collection("questProgress")

        listener?.remove()
        listener = col.addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let e = err {
                self.errorMessage = e.localizedDescription
                return
            }
            let progresses = snap?.documents.compactMap { doc in
                try? doc.data(as: QuestProgress.self)
            } ?? []

            // Sort: failed first, then available by availableAt
            let sorted = progresses.sorted { a, b in
                func priority(_ qp: QuestProgress) -> Int {
                    switch qp.status {
                    case .failed:    return 0
                    case .available: return 1
                    default:         return 2
                    }
                }
                let pa = priority(a), pb = priority(b)
                if pa != pb { return pa < pb }
                let ta = a.availableAt ?? Date.distantFuture
                let tb = b.availableAt ?? Date.distantFuture
                return ta < tb
            }

            guard let next = sorted.first else {
                self.current = nil
                self.questDetail = nil
                self.stopTimer()
                return
            }
            self.current = next
            self.fetchQuestDetail(for: next)
            if next.status == .available, let exp = next.expirationTime {
                self.startTimer(until: exp)
            } else {
                self.stopTimer()
            }
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
                let q    = Quest(from: data, id: snap!.documentID)
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
        timer?.invalidate()
        countdown = max(0, end.timeIntervalSinceNow)
        timer = Timer.scheduledTimer(
            withTimeInterval: 1, repeats: true
        ) { [weak self] t in
            guard let self = self else { return }
            self.countdown = max(0, end.timeIntervalSinceNow)
            if self.countdown <= 0 {
                t.invalidate()
                self.failCurrent()
            }
        }
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
        restEndHour: Int,   restEndMinute: Int
    ) -> Date {
        print("adjustDateConsderinRest run")
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: baseDate)
        guard let hour = comps.hour, let minute = comps.minute else { return baseDate }
        let overnight = restStartHour >= restEndHour
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
        guard inRest else { return baseDate }

        var endComps = cal.dateComponents([.year, .month, .day], from: baseDate)
        endComps.hour   = restEndHour
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

        let sysRef = db.collection("questSystems").document(sysId)
        sysRef.getDocument { [weak self] snap, err in
            guard let self = self, let data = snap?.data(), err == nil else { return }
            let defaultTTC: TimeIntervalConfig
            if
                let dict = data["defaultTimeToComplete"] as? [String:Any],
                let a    = dict["amount"] as? Double,
                let u    = dict["unit"]   as? String
            {
                defaultTTC = TimeIntervalConfig(amount: a, unit: u)
            } else {
                defaultTTC = TimeIntervalConfig(amount: 0, unit: "seconds")
            }

            let col = self.db
                .collection("users").document(uid)
                .collection("activeQuestSystems").document(aqsId)
                .collection("questProgress")

            col.getDocuments { snap2, err2 in
                guard let docs = snap2?.documents, err2 == nil else { return }
                var byRank: [Int: [(QuestProgress,Quest)]] = [:]
                let group = DispatchGroup()

                for doc in docs {
                    if let qp = try? doc.data(as: QuestProgress.self) {
                        group.enter()
                        qp.questRef.getDocument { qsnap, _ in
                            defer { group.leave() }
                            if
                                let qsnap = qsnap,
                                let qdata = qsnap.data(),
                                let q     = Quest(from: qdata, id: qsnap.documentID)
                            {
                                byRank[q.questRank, default: []].append((qp,q))
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    let ranks = byRank.keys.sorted()
                    for rank in ranks {
                        let entries     = byRank[rank] ?? []
                        let required    = entries.filter { $0.1.isRequired }
                        let allDone     = required.allSatisfy { $0.0.status == .completed }
                        guard allDone else { continue }

                        let nextLocked = (byRank[rank+1] ?? []).filter { $0.0.status == .locked }
                        guard !nextLocked.isEmpty else { continue }

                        let latest = required.compactMap { $0.0.expirationTime }.max() ?? Date()
                        UserProfileService.shared.fetchUserProfile(for: uid) { profile, _ in
                            let rsH = profile?.restStartHour   ?? 22
                            let rsM = profile?.restStartMinute ??  0
                            let reH = profile?.restEndHour     ??  6
                            let reM = profile?.restEndMinute   ??  0
                            let avail = self.adjustedDateConsideringRest(
                                latest,
                                restStartHour:   rsH, restStartMinute: rsM,
                                restEndHour:     reH, restEndMinute:   reM
                            )
                            let batch = self.db.batch()
                            for (qp,q) in nextLocked {
                                let cfg = q.timeToCompleteOverride ?? defaultTTC
                                let dur: TimeInterval = {
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
                            batch.commit { _ in }
                        }
                        break
                    }
                }
            }
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
