import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MatchListViewModel()
    @State private var selectedTab: MatchTab = .new
    @State private var searchText = ""

    private func matches(for tab: MatchTab) -> [StoredMatch] {
        viewModel.matches.filter { match in
            tab.includes(match)
                && (searchText.isEmpty || match.matchesSearch(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                content

                if let message = viewModel.errorMessage, !viewModel.matches.isEmpty {
                    StatusBanner(message: message)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)

                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.dismissErrorMessage(matching: message)
                                }
                            }
                        }
                }
            }
            .navigationTitle(selectedTab.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: selectedTab.searchPrompt
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.fetchMatches()
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh matches")
                }
            }
            .task {
                viewModel.configure(modelContext: modelContext)
                viewModel.fetchMatches()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if shouldShowLoading {
            LoadingStateView()
        } else if viewModel.matches.isEmpty, let errorMessage = viewModel.errorMessage {
            ErrorStateView(message: errorMessage) {
                viewModel.fetchMatches()
            }
        } else if viewModel.matches.isEmpty {
            EmptyStateView {
                viewModel.fetchMatches()
            }
        } else {
            matchTabs
        }
    }

    private var matchTabs: some View {
        TabView(selection: $selectedTab) {
            matchTabContent(for: .new)
                .tag(MatchTab.new)
                .tabItem {
                    Label(MatchTab.new.title, systemImage: MatchTab.new.systemImage)
                }

            matchTabContent(for: .accepted)
                .tag(MatchTab.accepted)
                .tabItem {
                    Label(MatchTab.accepted.title, systemImage: MatchTab.accepted.systemImage)
                }

            matchTabContent(for: .declined)
                .tag(MatchTab.declined)
                .tabItem {
                    Label(MatchTab.declined.title, systemImage: MatchTab.declined.systemImage)
                }
        }
    }

    private func matchTabContent(for tab: MatchTab) -> some View {
        MatchListView(
            viewModel: viewModel,
            matches: matches(for: tab),
            allMatches: viewModel.matches,
            tab: tab,
            searchText: searchText,
            clearSearch: {
                searchText = ""
            }
        )
    }

    private var shouldShowLoading: Bool {
        viewModel.matches.isEmpty
            && viewModel.errorMessage == nil
            && (viewModel.isLoading || !viewModel.hasCompletedInitialLoad)
    }
}

private struct MatchListView: View {
    @ObservedObject var viewModel: MatchListViewModel
    let matches: [StoredMatch]
    let allMatches: [StoredMatch]
    let tab: MatchTab
    let searchText: String
    let clearSearch: () -> Void

    var body: some View {
        List {
            SummaryHeaderView(matches: allMatches)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if viewModel.isOffline {
                ListStatusRow(
                    title: "Offline mode",
                    systemImage: "wifi.slash"
                )
            }

            if viewModel.isOffline && viewModel.pendingSyncCount > 0 {
                ListStatusRow(
                    title: "\(viewModel.pendingSyncCount) decision\(viewModel.pendingSyncCount == 1 ? "" : "s") saved offline",
                    systemImage: "clock"
                )
            }

            if matches.isEmpty {
                TabEmptyStateView(
                    tab: tab,
                    searchText: searchText,
                    clearSearch: clearSearch
                )
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(matches, id: \.userID) { match in
                    MatchCardView(
                        match: match,
                        onAccept: {
                            viewModel.accept(match)
                        },
                        onDecline: {
                            viewModel.decline(match)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        .refreshable {
            viewModel.fetchMatches()
        }
    }
}

private enum MatchTab: CaseIterable, Identifiable {
    case new
    case accepted
    case declined

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .new:
            return "Matches"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        }
    }

    var navigationTitle: String {
        switch self {
        case .new:
            return "MatchMate"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        }
    }

    var systemImage: String {
        switch self {
        case .new:
            return "sparkles"
        case .accepted:
            return "checkmark.circle.fill"
        case .declined:
            return "xmark.circle.fill"
        }
    }

    var searchPrompt: String {
        switch self {
        case .new:
            return "Search new matches"
        case .accepted:
            return "Search accepted matches"
        case .declined:
            return "Search declined matches"
        }
    }

    func includes(_ match: StoredMatch) -> Bool {
        switch self {
        case .new:
            return match.decision == nil
        case .accepted:
            return match.decision == .accepted
        case .declined:
            return match.decision == .declined
        }
    }
}

private struct SummaryHeaderView: View {
    let matches: [StoredMatch]

    private var acceptedCount: Int {
        matches.filter { $0.decision == .accepted }.count
    }

    private var declinedCount: Int {
        matches.filter { $0.decision == .declined }.count
    }

    private var newCount: Int {
        matches.filter { $0.decision == nil }.count
    }

    var body: some View {
        HStack(spacing: 10) {
            SummaryMetricView(value: matches.count, title: "Matches", systemImage: "person.2.fill", tint: .pink)
            SummaryMetricView(value: newCount, title: "New", systemImage: "sparkles", tint: .orange)
            SummaryMetricView(value: acceptedCount, title: "Accepted", systemImage: "checkmark.circle.fill", tint: .green)
            SummaryMetricView(value: declinedCount, title: "Declined", systemImage: "xmark.circle.fill", tint: .red)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SummaryMetricView: View {
    let value: Int
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())

            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ListStatusRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.12))
                    .frame(width: 72, height: 72)

                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: 4) {
                Text("Finding matches")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Loading profiles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyStateView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.pink)
                .frame(width: 76, height: 76)
                .background(Color.pink.opacity(0.12), in: Circle())

            VStack(spacing: 6) {
                Text("No matches available")
                    .font(.title3.weight(.semibold))

                Text("Check your connection and refresh.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 76, height: 76)
                .background(Color.orange.opacity(0.12), in: Circle())

            VStack(spacing: 6) {
                Text("Unable to load matches")
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct TabEmptyStateView: View {
    let tab: MatchTab
    let searchText: String
    let clearSearch: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.12), in: Circle())

            Text(emptyTitle)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Label("Clear Search", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "No results for \"\(searchText)\""
        }

        switch tab {
        case .new:
            return "No new matches"
        case .accepted:
            return "No accepted matches"
        case .declined:
            return "No declined matches"
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "Try a different name, city, company, email, or phone."
        }

        switch tab {
        case .new:
            return "Accepted and declined profiles are moved to their own tabs."
        case .accepted:
            return "Profiles you accept will appear here."
        case .declined:
            return "Profiles you decline will appear here."
        }
    }

    private var systemImage: String {
        switch tab {
        case .new:
            return "sparkles"
        case .accepted:
            return "checkmark.circle"
        case .declined:
            return "xmark.circle"
        }
    }

    private var tint: Color {
        switch tab {
        case .new:
            return .pink
        case .accepted:
            return .green
        case .declined:
            return .red
        }
    }
}

private struct StatusBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.orange, in: Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            .padding(.horizontal)
    }
}

private extension StoredMatch {
    func matchesSearch(_ text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return true
        }

        return [
            name,
            companyName,
            city,
            email,
            phone
        ]
        .contains { value in
            value.localizedCaseInsensitiveContains(query)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: StoredMatch.self, inMemory: true)
    }
}
