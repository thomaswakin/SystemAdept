//  ActiveSystemsViewModel.swift
//  SystemAdept
//
//  Created by Thomas Akin on 4/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Manages the list of quest systems the user has activated,
/// and triggers automatic quest‑unlocking refresh for each.
/// Also fetches the list of available systems for routing when no active.
final class ActiveSystemsViewModel: ObservableObject {
    // MARK: - Published
    @Published var activeSystems: [ActiveQuestSystem] = []
    @Published var availableSystems: [QuestSystem] = []      // newly added
    @Published var didLoadActive: Bool = false
    @Published var didLoadAvailable: Bool = false
    @Published var errorMessage: String?

    private var hasLoadedActive = false
    private var hasLoadedAvailable = false

    // MARK: - Private
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    /// Hold onto each QuestQueueViewModel so its periodicTimer isn't deallocated
    private var queueVMs: [String: QuestQueueViewModel] = [:]
    
    // MARK: - Init / Deinit
    init() {
        startListeningActive()
        fetchAvailableSystems()
    }

    deinit {
        listener?.remove()
    }
    
    // MARK: - Listen for Active Systems
    private func startListeningActive() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let coll = db
            .collection("users")
            .document(uid)
            .collection("activeQuestSystems")

        listener = coll.addSnapshotListener { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }

            let docs = snap?.documents ?? []
            var newSystems: [ActiveQuestSystem] = []
            for doc in docs {
                let data = doc.data()
                guard
                    let qsr       = data["questSystemRef"]   as? DocumentReference,
                    let statusStr = data["status"]           as? String,
                    let status    = SystemAssignmentStatus(rawValue: statusStr),
                    let ts        = data["assignedAt"]       as? Timestamp
                else { continue }

                let name = data["questSystemName"] as? String ?? qsr.documentID
                let isSelected: Bool = {
                    if let b = data["isUserSelected"] as? Bool { return b }
                    if let i = data["isUserSelected"] as? Int  { return i != 0 }
                    return false
                }()
                let currentQuestRef = data["currentQuestRef"] as? DocumentReference

                newSystems.append(
                    ActiveQuestSystem(
                        id: doc.documentID,
                        questSystemRef:   qsr,
                        questSystemName:  name,
                        isUserSelected:   isSelected,
                        assignedAt:       ts.dateValue(),
                        status:           status,
                        currentQuestRef:  currentQuestRef
                    )
                )
            }

            // Publish active systems
            self.activeSystems = newSystems
            if !self.hasLoadedActive {
                self.didLoadActive = true
                self.hasLoadedActive = true
            }

            // Trigger refresh/unlock for each active system
            for aqs in newSystems {
                if let vm = self.queueVMs[aqs.id] {
                    vm.refreshAvailableQuests()
                } else {
                    let vm = QuestQueueViewModel(activeSystem: aqs)
                    self.queueVMs[aqs.id] = vm
                    vm.refreshAvailableQuests()
                }
            }
            // Clean up removed VMs
            let activeIds = Set(newSystems.map(\.id))
            self.queueVMs.keys.filter { !activeIds.contains($0) }
                .forEach { self.queueVMs.removeValue(forKey: $0) }
        }
    }

    // MARK: - Fetch Available Systems
    private func fetchAvailableSystems() {
        let coll = db.collection("questSystems")
        coll.getDocuments(completion: { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            let docs = snapshot?.documents ?? []
            // Use the failable initializer in QuestSystem
            let systems = docs.compactMap { QuestSystem(from: $0) }
            self.availableSystems = systems
            if !self.hasLoadedAvailable {
                self.didLoadAvailable = true
                self.hasLoadedAvailable = true
            }
        })
    }


    // MARK: - User Actions
    func togglePause(system: ActiveQuestSystem) {
        let queueVM = QuestQueueViewModel(activeSystem: system)
        system.status == .active
            ? queueVM.pauseSystem()
            : queueVM.resumeSystem()
    }

    func stop(system: ActiveQuestSystem) {
        updateStatus(aqsId: system.id, status: .stopped)
    }

    // MARK: - Helpers
    private func updateStatus(aqsId: String, status: SystemAssignmentStatus) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db
            .collection("users")
            .document(uid)
            .collection("activeQuestSystems")
            .document(aqsId)

        ref.updateData(["status": status.rawValue]) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

