# MatchMate Project Documentation

## Overview

MatchMate is a native iOS SwiftUI application that displays a list of simulated matrimonial matches. It fetches profile data from JSONPlaceholder, stores profiles locally with SwiftData, lets users accept or decline matches, and keeps decisions available offline until they can be synced.

The project follows a lightweight MVVM structure:

- `Views` render state and send user actions.
- `ViewModels` manage presentation state and app flow.
- `Services` handle API calls, persistence, connectivity, and decision sync.
- `Models` define API payloads, stored data, decisions, and app errors.

## Main Features

- Fetches profiles from `https://jsonplaceholder.typicode.com/users`.
- Displays matches in a SwiftUI list with profile images, match score, contact details, and decision actions.
- Groups profiles into `Matches`, `Accepted`, and `Declined` tabs.
- Supports search by name, company, city, email, and phone.
- Persists fetched profiles and user decisions with SwiftData.
- Shows cached profiles when the device is offline or the API request fails.
- Saves accept/decline actions offline and syncs them when connectivity returns.
- Loads profile images with `SDWebImageSwiftUI`.

## Requirements

- iOS 17.0 or later
- Xcode with iOS development tools installed
- SwiftData support
- Swift Package Manager dependencies restored by Xcode

## Dependencies

The project currently uses:

- `SDWebImageSwiftUI` for remote image loading and caching.
- `SDWebImage`, pulled in as a package dependency.

The app also uses Apple frameworks:

- `SwiftUI` for the UI
- `SwiftData` for local persistence
- `Combine` for publisher-based async flows
- `Network` for connectivity monitoring

## How To Run

1. Open `MatchMate.xcodeproj` in Xcode.
2. Let Xcode resolve Swift Package Manager dependencies.
3. Select the `MatchMate` scheme.
4. Choose an iOS simulator or device running iOS 17.0 or later.
5. If running on a real device, select a signing team if needed.
6. Build and run the app.

## Architecture

### App Entry

`MatchMateApp` creates the SwiftUI window and attaches a SwiftData model container for `StoredMatch`. This makes a `ModelContext` available through the SwiftUI environment.

### View Layer

`ContentView` owns screen-level UI state such as the selected tab and search text. It creates `MatchListViewModel`, configures it with the SwiftData `ModelContext`, and calls `fetchMatches()` when the screen loads.

`MatchCardView` renders an individual profile card. It receives callbacks for accept and decline actions, so it does not need to know how persistence or sync works.

### View Model Layer

`MatchListViewModel` is the coordination point for user-facing state. It:

- Loads cached matches during setup.
- Fetches fresh matches through the repository.
- Falls back to cached matches on request failure.
- Applies accept/decline decisions.
- Tracks offline state and pending sync count.
- Observes connectivity changes.
- Syncs unsynced decisions when the device is connected.

### Repository Layer

`MatchRepository` combines network and persistence work behind `MatchRepositoryProtocol`. The view model asks the repository for match data without needing to know whether the source is the API, SwiftData, or both.

### Service Layer

`MatchAPIService` fetches profile data from JSONPlaceholder.

`MatchPersistenceService` reads, inserts, updates, and saves `StoredMatch` records in SwiftData.

`MatchDecisionSyncService` posts saved accept/decline decisions to JSONPlaceholder. This simulates a backend sync endpoint.

`ConnectivityMonitor` wraps `NWPathMonitor` and exposes connectivity as a Combine publisher.

## Data Flow

### Initial Load

1. `ContentView` calls `viewModel.configure(modelContext:)`.
2. The view model creates a repository through `MatchRepositoryFactory`.
3. Cached matches are loaded from SwiftData.
4. The view model starts observing connectivity.
5. `ContentView` calls `viewModel.fetchMatches()`.
6. The repository fetches profiles from the API.
7. The persistence service upserts profiles into SwiftData.
8. The updated cached matches are returned to the UI.

### Profile Refresh

When fresh profiles arrive, `MatchPersistenceService.upsertMatches(from:)` matches records by `userID`.

- Existing records have profile fields updated.
- New records are inserted.
- Existing accept/decline decisions are preserved.
- Duplicate API profiles in the same response are ignored.

### Accept Or Decline

1. The user taps `Accept` or `Decline` in `MatchCardView`.
2. `ContentView` forwards the action to `MatchListViewModel`.
3. The view model updates the decision through the repository.
4. `StoredMatch.applyLocalDecision(_:)` marks the decision as unsynced.
5. If the device is online, sync starts immediately.
6. If the device is offline, the decision remains saved locally for later sync.

### Offline Sync

When connectivity returns:

1. `ConnectivityMonitor` emits the new online state.
2. The view model calls `syncPendingDecisions()`.
3. Unsynced matches are sent through `MatchDecisionSyncService`.
4. Each successful sync marks its decision as synced.
5. Failed syncs keep their pending state and store an error message.
6. The pending sync count refreshes for the UI.

## Important Files

| File | Purpose |
| --- | --- |
| `MatchMate/MatchMateApp.swift` | App entry point and SwiftData container setup |
| `MatchMate/Views/ContentView.swift` | Main screen, tabs, search, loading, empty, and error states |
| `MatchMate/Views/MatchCardView.swift` | Profile card UI and accept/decline controls |
| `MatchMate/ViewModels/MatchListViewModel.swift` | Presentation state, loading, offline fallback, and sync orchestration |
| `MatchMate/Services/MatchRepository.swift` | Boundary between view model, API, and persistence |
| `MatchMate/Services/MatchAPIService.swift` | Fetches match profiles from the remote API |
| `MatchMate/Services/MatchPersistenceService.swift` | SwiftData fetch, upsert, decision, and sync-state updates |
| `MatchMate/Services/MatchDecisionSyncService.swift` | Posts saved decisions to the simulated sync endpoint |
| `MatchMate/Services/ConnectivityMonitor.swift` | Publishes online and offline state |
| `MatchMate/Models/StoredMatch.swift` | SwiftData model used for cached profiles and decision state |
| `MatchMate/Models/MatchProfile.swift` | API response model |
| `MatchMate/Models/MatchDecision.swift` | Accepted and declined decision values |
| `MatchMate/Models/MatchMateError.swift` | User-friendly app error mapping |

## Notes For Future Development

- Replace JSONPlaceholder with a real match API when backend endpoints are available.
- Move generated age and match score logic to backend data when real profile fields exist.
- Add unit tests around `MatchListViewModel`, `MatchPersistenceService`, and error mapping.
- Add a retry strategy or backoff for repeated decision sync failures.
- Consider conflict handling if a decision can be changed on another device.
- Add a dedicated settings or diagnostics screen if offline sync behavior becomes more complex.
