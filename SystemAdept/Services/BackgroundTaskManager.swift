import Foundation
import BackgroundTasks
import FirebaseAuth
import FirebaseFirestore

/// Coordinates periodic background maintenance (expire/unlock quests).
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private let taskID = "com.sirthomasraine.SystemAdept.maintenance"

    private init() {
        // 1) Register the background refresh task handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskID,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// Call this once at app launch to queue up the first refresh.
    func scheduleAppRefresh() {
        print("BackGroundTaskManager: Scheduling app refresh")
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        // Earliest next run: 15 minutes from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Could not schedule app refresh: \(error)")
        }
    }

    /// System calls this when the background refresh fires.
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("BackGroundTaskManager: Handling app refresh")
        // Always schedule the next
        scheduleAppRefresh()

        // Perform your maintenance and report completion
        performMaintenance { success in
            task.setTaskCompleted(success: success)
        }

        // If task expires early, mark as failed
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }

    /// Fetches user's active systems and runs the same maintenance logic as foreground.
    private func performMaintenance(completion: @escaping (Bool) -> Void) {
        print("BackGroundTaskManager: Performing maintenance")
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        let db = Firestore.firestore()
        let col = db
            .collection("users").document(uid)
            .collection("activeQuestSystems")

        col.getDocuments { snap, err in
            if let err = err {
                print("❌ BG fetch active systems error: \(err)")
                completion(false)
                return
            }
            let docs = snap?.documents ?? []
            for doc in docs {
                let data = doc.data()
                // Required fields
                guard
                    let qsr   = data["questSystemRef"] as? DocumentReference,
                    let isSel = data["isUserSelected"] as? Bool,
                    let ts    = data["assignedAt"] as? Timestamp,
                    let statusStr = data["status"] as? String,
                    let status = SystemAssignmentStatus(rawValue: statusStr)
                else {
                    print("⚠️ BG maintenance: missing fields for system \(doc.documentID)")
                    continue
                }
                // Optional currentQuestRef
                let currentRef = data["currentQuestRef"] as? DocumentReference
                let system = ActiveQuestSystem(
                    id: doc.documentID,
                    questSystemRef: qsr,
                    questSystemName: data["questSystemName"] as? String ?? "",
                    isUserSelected: isSel,
                    assignedAt: ts.dateValue(),
                    status: status,
                    currentQuestRef: currentRef
                )
                // Run the same maintenance you use on foreground
                QuestQueueViewModel.runMaintenance(for: system)
            }
            completion(true)
        }
    }
}

