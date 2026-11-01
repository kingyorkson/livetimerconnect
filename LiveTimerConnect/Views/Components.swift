import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat
    let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?

    init(_ title: String, subtitle: String? = nil, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if let trailing {
                trailing
            }
        }
    }
}

struct SyncStatusPill: View {
    let status: CloudSyncManager.Status

    private var tint: Color {
        switch status {
        case .checking, .syncing:
            return AppTheme.blue
        case .synced:
            return AppTheme.green
        case .unavailable:
            return AppTheme.orange
        case .error:
            return AppTheme.red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.symbolName)
                .font(.system(size: 11, weight: .bold))
            Text(status.shortText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.13)))
        .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
        .accessibilityLabel("iCloud status: \(status.shortText)")
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.green)
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.78))
                .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(AppTheme.orange)
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(AppTheme.card.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(AppTheme.stroke)
        )
    }
}

struct CircleIconButton: View {
    let systemName: String
    var tint: Color = .white
    var background: Color = AppTheme.cardStrong
    var size: CGFloat = 42
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
                .overlay(Circle().stroke(AppTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch systemName {
        case "pause.fill": return "Pause timer"
        case "play.fill": return "Resume timer"
        case "stop.fill", "xmark": return "Stop timer"
        case "arrow.counterclockwise": return "Restart timer"
        default: return systemName
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let detail: String
    var tint: Color = AppTheme.orange

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.13)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
