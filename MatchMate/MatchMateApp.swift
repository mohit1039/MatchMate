import SwiftUI
import SwiftData

@main
struct MatchMateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Provides the SwiftData context that ContentView passes into the view model.
        .modelContainer(for: StoredMatch.self)
    }
}
