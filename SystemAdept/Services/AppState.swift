// AppState.swift
// SystemAdept
//
// Created by Your Name on 4/27/25.
//

import SwiftUI
import Combine

/// Central app state and routing, now with notification scheduling.
final class AppState: ObservableObject {
    enum Tab: Int, Hashable, CaseIterable {
        case player = 0, systems = 1, quests = 2
    }

    // MARK: Published for UI
    @Published var selectedTab: Tab?
    @Published var initialQuestPage: MyQuestsView.Page?
    @Published var notificationMessage: String? = nil
    @Published var hasRouted: Bool = false

    // MARK: Dependencies
    private let activeSystemsVM: ActiveSystemsViewModel
    private let questsVM: MyQuestsViewModel
    private let authVM: AuthViewModel

    private var cancellables = Set<AnyCancellable>()

    /// Initialize with view-models and auth for notifications.
    init(
        activeSystemsVM: ActiveSystemsViewModel,
        questsVM: MyQuestsViewModel,
        authVM: AuthViewModel
    ) {
        self.activeSystemsVM = activeSystemsVM
        self.questsVM        = questsVM
        self.authVM          = authVM

        // 1a) If there are no active systems at all → route immediately
        activeSystemsVM.$activeSystems
            .prefix(1)
            .sink { [weak self] systems in
                guard let self = self else { return }
                if systems.isEmpty {
                    self.selectedTab      = .systems
                    self.initialQuestPage = .daily
                    self.hasRouted        = true
                    self.scheduleNotifications()
                }
            }
            .store(in: &cancellables)

        // 1b) If systems exist, wait for both systems & quests before routing
        let combined = activeSystemsVM.$activeSystems
            .combineLatest(questsVM.$activeQuests)
            .receive(on: DispatchQueue.main)
            .share()

        combined
            .filter { systems, quests in
                !systems.isEmpty && !quests.isEmpty
            }
            .prefix(1)
            .sink { [weak self] systems, quests in
                guard let self = self else { return }
                self.route(systems: systems, quests: quests)
                self.hasRouted = true
                self.scheduleNotifications()
            }
            .store(in: &cancellables)

        // 2) After startup, update banner & expiry alerts whenever quests change
        combined
            .dropFirst()
            .sink { [weak self] systems, quests in
                guard let self = self else { return }
                self.updateNotification(systems: systems, quests: quests)
                NotificationManager.shared.scheduleExpiryAlerts(activeQuests: quests)
            }
            .store(in: &cancellables)

        // 3) Whenever userProfile changes (rest cycle edits), re-schedule morning reminder
        authVM.$userProfile
            .compactMap { $0 }
            .sink { [weak self] _ in
                self?.scheduleNotifications()
            }
            .store(in: &cancellables)
    }

    // MARK: One-time routing logic
    private func route(
        systems: [ActiveQuestSystem],
        quests: [ActiveQuest]
    ) {
        notificationMessage = nil
        selectedTab = .quests

        let available = quests.filter { $0.progress.status == .available }
        let failed    = quests.filter { $0.progress.status == .failed }
        let locked    = quests.filter { $0.progress.status == .locked }

        if !available.isEmpty {
            let now = Date()
            let todaySpan = Calendar.current.dateInterval(of: .day, for: now)!
            if available.contains(where: {
                guard let exp = $0.progress.expirationTime else { return false }
                return todaySpan.contains(exp)
            }) {
                initialQuestPage = .daily
            } else {
                initialQuestPage = .active
            }
            return
        }

        if !failed.isEmpty {
            initialQuestPage = .expired
            return
        }

        if !locked.isEmpty {
            initialQuestPage    = .daily
            notificationMessage = "Waiting on next quest"
            return
        }

        // fallback
        initialQuestPage = .daily
    }

    // MARK: Dynamic banner updates
    private func updateNotification(
        systems: [ActiveQuestSystem],
        quests: [ActiveQuest]
    ) {
        guard hasRouted, !systems.isEmpty else {
            notificationMessage = nil
            return
        }

        // clear if any available or failed
        if quests.contains(where: { [.available, .failed].contains($0.progress.status) }) {
            notificationMessage = nil
            return
        }

        // locked-only → waiting or countdown
        let locked = quests.filter { $0.progress.status == .locked }
        let dates  = locked.compactMap { $0.progress.availableAt }

        if !locked.isEmpty && dates.isEmpty {
            notificationMessage = "Waiting on next quest"
            return
        }
        if let next = dates.min() {
            let f = DateComponentsFormatter()
            f.allowedUnits = [.hour, .minute]
            f.unitsStyle   = .full
            let delta = f.string(from: Date(), to: next) ?? "soon"
            notificationMessage = "Next Quest Available in \(delta)"
            return
        }

        notificationMessage = nil
    }

    // MARK: Notification scheduling helper
    private func scheduleNotifications() {
        let profile = authVM.userProfile
        let restEndHour   = profile?.restEndHour   ?? 6
        let restEndMinute = profile?.restEndMinute ?? 0
        let quests        = questsVM.activeQuests

        NotificationManager.shared.scheduleNextMorningReminder(
            restEndHour:   restEndHour,
            restEndMinute: restEndMinute,
            activeQuests:  quests,
            authVM:        authVM,
            appState:      self
        )
        NotificationManager.shared.scheduleExpiryAlerts(activeQuests: quests)
    }
}
