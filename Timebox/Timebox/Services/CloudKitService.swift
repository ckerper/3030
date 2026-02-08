import Foundation
import Combine

/// CloudKit sync service using NSUbiquitousKeyValueStore for lightweight iCloud sync.
/// No login required — syncs automatically via the user's Apple ID.
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    @Published var lastSyncDate: Date?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Start observing iCloud key-value store changes
        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.handleExternalChange(notification)
        }
        .store(in: &cancellables)

        // Sync on launch
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        else { return }

        switch changeReason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            // Data changed on another device — post notification for ViewModels to reload
            lastSyncDate = Date()
            NotificationCenter.default.post(name: .iCloudDataDidChange, object: nil)
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            // Over the 1MB limit for KVS — would need to migrate to full CloudKit
            print("iCloud KVS quota exceeded")
        default:
            break
        }
    }

    func forceSyncNow() {
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}

extension Notification.Name {
    static let iCloudDataDidChange = Notification.Name("iCloudDataDidChange")
}
