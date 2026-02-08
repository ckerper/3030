import SwiftUI

@main
struct TimekerperApp: App {
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
