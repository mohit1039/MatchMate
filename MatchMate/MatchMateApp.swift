import SwiftUI
import SwiftData

@main
struct MatchMateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: StoredMatch.self)
    }
}
