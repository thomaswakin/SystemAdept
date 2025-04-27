//
//  AppState.swift
//  SystemAdept
//
//  Created by Your Name on 4/27/25.
//

import SwiftUI
import Combine

final class AppState: ObservableObject {
    enum Tab: Hashable { case player, systems, quests }

    // MARK: – Published for UI
    @Published var selectedTab: Tab?
    @Published var initialQuestPage: MyQuestsView.Page?
    @Published var notificationMessage: String? = nil
    @Published var hasRouted: Bool = false

    private var cancellables = Set<AnyCancellable>()

    /// Inject your two VMs here.
    init(
        activeSystemsVM: ActiveSystemsViewModel,
        questsVM: MyQuestsViewModel
    ) {
        // 1) Watch for the first ActiveSystems snapshot (didLoadActive)
        activeSystemsVM.$didLoadActive
            .filter { $0 }       // only once, when systems arrive
            .prefix(1)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let systems = activeSystemsVM.activeSystems

                if systems.isEmpty {
                    // ――― No active systems ―――
                    self.selectedTab      = .systems
                    self.initialQuestPage = .daily
                    self.hasRouted        = true

                } else {
                    // ――― We have systems ――― wait for quests to load
                    questsVM.$didLoadInitial
                        .filter { $0 }   // once first quests arrive
                        .prefix(1)
                        .receive(on: DispatchQueue.main)
                        .sink { [weak self] _ in
                            guard let self = self else { return }
                            self.route(
                                systems: systems,
                                quests: questsVM.activeQuests
                            )
                            self.hasRouted = true
                        }
                        .store(in: &self.cancellables)
                }
            }
            .store(in: &cancellables)

        // 2) After startup, only update the banner (no re-routing)
        Publishers.CombineLatest(
            activeSystemsVM.$activeSystems,
            questsVM.$activeQuests
        )
        .dropFirst()  // ignore the very first emission
        .receive(on: DispatchQueue.main)
        .sink { [weak self] systems, quests in
            self?.updateNotification(systems: systems, quests: quests)
        }
        .store(in: &cancellables)
    }

    // MARK: – One-time startup routing
    private func route(
        systems: [ActiveQuestSystem],
        quests: [ActiveQuest]
    ) {
        notificationMessage = nil
        selectedTab = .quests

        // Partition quests
        let available = quests.filter { $0.progress.status == .available }
        let failed    = quests.filter { $0.progress.status == .failed }
        let locked    = quests.filter { $0.progress.status == .locked }

        // 1) Available quests?
        if !available.isEmpty {
            // 1a) Any due today → Daily
            let now = Date()
            let todaySpan = Calendar.current.dateInterval(of: .day, for: now)!
            if available.contains(where: {
                if let exp = $0.progress.expirationTime {
                    return todaySpan.contains(exp)
                }
                return false
            }) {
                initialQuestPage = .daily
            } else {
                // 1b) Available but not due today → All Active
                initialQuestPage = .active
            }
            return
        }

        // 2) No available → Any failed? → Expired
        if !failed.isEmpty {
            initialQuestPage = .expired
            return
        }

        // 3) No available or failed → Any locked?
        if !locked.isEmpty {
            // Locked only: show waiting/countdown in banner (Daily page)
            initialQuestPage   = .daily
            notificationMessage = "Waiting on next quest"
            return
        }

        // 4) No quests at all → fallback Daily
        initialQuestPage = .daily
    }

    // MARK: – Dynamic banner updates
    private func updateNotification(
        systems: [ActiveQuestSystem],
        quests: [ActiveQuest]
    ) {
        // Only after routing
        guard hasRouted, !systems.isEmpty else {
            notificationMessage = nil
            return
        }

        // If any available or failed, clear banner
        if quests.contains(where: {
            [.available, .failed].contains($0.progress.status)
        }) {
            notificationMessage = nil
            return
        }

        // Only locked remain → countdown or waiting
        let locked          = quests.filter { $0.progress.status == .locked }
        let lockedWithDates = locked.compactMap { $0.progress.availableAt }

        // If none have dates → waiting
        if !locked.isEmpty && lockedWithDates.isEmpty {
            notificationMessage = "Waiting on next quest"
            return
        }

        // Else some have future unlocks → countdown
        if let next = lockedWithDates.min() {
            let f = DateComponentsFormatter()
            f.allowedUnits = [.hour, .minute]
            f.unitsStyle   = .full
            let delta = f.string(from: Date(), to: next) ?? "soon"
            notificationMessage = "Next Quest Available in \(delta)"
            return
        }

        // Otherwise clear
        notificationMessage = nil
    }
}

