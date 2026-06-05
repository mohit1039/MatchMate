# MatchMate

MatchMate is a native iOS SwiftUI app scaffold that simulates a matrimonial match list.

Current implementation:

- SwiftUI app project
- MVVM folder structure
- Combine-powered `URLSession` API layer
- Fetches users from `https://jsonplaceholder.typicode.com/users`
- Displays profiles as match cards inside a SwiftUI `List`
- Persists match data and accepted/declined decisions with SwiftData
- Caches fetched profiles for offline display
- Merges fresh API profiles into SwiftData by inserting missing users and updating existing profile fields while preserving decisions
- Allows accept/decline decisions while offline and syncs pending decisions when connectivity returns
- Loads and caches profile images with SDWebImageSwiftUI
- Requires iOS 17.0 or later

Architecture notes:

- Views render SwiftUI state and forward user intent only.
- `MatchListViewModel` owns presentation state and delegates data work to abstractions.
- `MatchRepositoryProtocol` coordinates API and SwiftData persistence behind one domain-facing boundary.
- API, sync, persistence, and connectivity each have focused protocols and concrete implementations.
- SwiftData models store match profile data, decision state, and sync metadata.

Open `MatchMate.xcodeproj` in Xcode, select a signing team if needed, then run the `MatchMate` scheme.
