import SwiftUI

@main
struct TimeboxApp: App {
    init() {
        // Start iCloud KVS sync on launch
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
