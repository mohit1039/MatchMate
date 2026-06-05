import SwiftUI
import SDWebImageSwiftUI

struct MatchCardView: View {
    let match: StoredMatch
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProfileImageView(match: match)

            VStack(alignment: .leading, spacing: 16) {
                header
                details
                profileNote
                actionRow
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(match.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                badge
            }

            Text(match.profileSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Label(match.companyName, systemImage: "briefcase.fill")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var badge: some View {
        Text("\(match.matchScore)% Match")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(red: 0.48, green: 0.20, blue: 0.12))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(red: 1.0, green: 0.87, blue: 0.74), in: Capsule())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(systemImage: "envelope.fill", text: match.email)
            InfoRow(systemImage: "phone.fill", text: match.phone)
        }
    }

    private var profileNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption.weight(.bold))
                .foregroundStyle(.pink)
                .frame(width: 18)

            Text(match.companyCatchPhrase)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.top, 2)
    }

    private var actionRow: some View {
        Group {
            if let decision = match.decision {
                DecisionStatusView(decision: decision)
            } else {
                HStack(spacing: 10) {
                    decisionButton(
                        title: "Decline",
                        systemImage: "xmark",
                        tint: .red,
                        action: onDecline
                    )

                    decisionButton(
                        title: "Accept",
                        systemImage: "checkmark",
                        tint: .green,
                        action: onAccept
                    )
                }
            }
        }
        .controlSize(.regular)
    }

    private func decisionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(tint)
        .accessibilityLabel(title)
    }
}

private struct InfoRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

private struct ProfileImageView: View {
    let match: StoredMatch

    var body: some View {
        WebImage(
            url: match.imageURL,
            options: [.retryFailed, .continueInBackground]
        ) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            fallbackAvatar
        }
        .indicator(.activity)
        .transition(.fade(duration: 0.25))
        .frame(maxWidth: .infinity)
        .frame(height: 253)
        .clipped()
        .accessibilityLabel("Profile image for \(match.name)")
    }

    private var fallbackAvatar: some View {
        ZStack {
            imageBackground

            Text(match.initials)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private var imageBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.88, green: 0.20, blue: 0.36),
                Color(red: 0.97, green: 0.57, blue: 0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct DecisionStatusView: View {
    let decision: MatchDecision

    var body: some View {
        Label(decision.title, systemImage: decision.systemImageName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
            .labelStyle(.titleAndIcon)
    }

    private var foregroundColor: Color {
        switch decision {
        case .accepted:
            return Color(red: 0.02, green: 0.38, blue: 0.20)
        case .declined:
            return Color(red: 0.55, green: 0.08, blue: 0.08)
        }
    }

    private var backgroundColor: Color {
        switch decision {
        case .accepted:
            return Color(red: 0.82, green: 0.95, blue: 0.87)
        case .declined:
            return Color(red: 1.0, green: 0.85, blue: 0.85)
        }
    }
}

struct MatchCardView_Previews: PreviewProvider {
    static var previews: some View {
        let match: StoredMatch = {
            let match = StoredMatch(profile: .preview)
            match.decision = .accepted
            return match
        }()

        MatchCardView(
            match: match,
            onAccept: {},
            onDecline: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
