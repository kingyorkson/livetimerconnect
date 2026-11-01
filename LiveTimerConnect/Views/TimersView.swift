import SwiftUI

struct TimersView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAddQuickTimer = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 160), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        quickTimerSection
                        activeSection
                        if !model.endedTimers.isEmpty {
                            endedSection
                        }
                    }
                    .frame(maxWidth: 920)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddQuickTimer) {
                AddQuickTimerView()
                    .environmentObject(model)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(AppTheme.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: AppTheme.green.opacity(0.8), radius: 5)

                    Text("LIVE TIMER CONNECT")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("Timers")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Tap a preset to start it on every device.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 8) {
                SyncStatusPill(status: model.sync.status)

                if model.runningTimerCount > 0 {
                    Text("\(model.runningTimerCount) running")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.orange.opacity(0.12)))
                }
            }
        }
    }

    private var quickTimerSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(
                "Quick Timers",
                subtitle: "Start anywhere. It follows you.",
                trailing: AnyView(
                    Button {
                        showingAddQuickTimer = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .black))
                            Text("Add")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.orange)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AppTheme.orange.opacity(0.12)))
                        .overlay(Capsule().stroke(AppTheme.orange.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                )
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(AppConstants.builtInQuickTimerDurations.enumerated()), id: \.offset) { index, duration in
                    QuickTimerCard(
                        duration: duration,
                        accent: quickTimerAccent(index),
                        isCustom: false
                    ) {
                        model.startTimer(duration: duration)
                    }
                }

                ForEach(model.customQuickTimers) { custom in
                    QuickTimerCard(
                        duration: custom.duration,
                        accent: AppTheme.green,
                        isCustom: true
                    ) {
                        model.startTimer(duration: custom.duration)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            model.deleteQuickTimer(custom.id)
                        } label: {
                            Label("Delete Quick Timer", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showingAddQuickTimer = true
                } label: {
                    VStack(spacing: 9) {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppTheme.orange)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(AppTheme.orange.opacity(0.12)))

                        Text("Add Quick Timer")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 118)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.025))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(AppTheme.stroke)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(
                "Active Timers",
                subtitle: model.activeTimers.isEmpty
                    ? "Nothing counting down right now."
                    : "Control them here or from the Lock Screen."
            )

            if model.activeTimers.isEmpty && model.endedTimers.isEmpty {
                EmptyStateCard(
                    icon: "timer",
                    title: "Ready when you are",
                    message: "Choose a quick timer above. Start it here and it starts on your other devices too."
                )
            } else {
                ForEach(model.activeTimers) { timer in
                    TimerCard(timer: timer, now: model.now)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .scale(scale: 0.96).combined(with: .opacity)))
                }
            }
        }
    }

    private var endedSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(
                "Ended",
                subtitle: "Restart from the beginning or clear it away."
            )

            ForEach(model.endedTimers) { timer in
                TimerCard(timer: timer, now: model.now)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    private func quickTimerAccent(_ index: Int) -> Color {
        let colors: [Color] = [
            AppTheme.orange,
            AppTheme.red,
            AppTheme.purple,
            AppTheme.blue,
            AppTheme.green,
            AppTheme.orange
        ]
        return colors[index % colors.count]
    }
}

private struct QuickTimerCard: View {
    let duration: TimeInterval
    let accent: Color
    let isCustom: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: isCustom ? "star.fill" : "timer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(accent.opacity(0.13)))

                    Spacer(minLength: 2)

                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 25, height: 25)
                        .background(Circle().fill(Color.white.opacity(0.09)))
                }

                Spacer(minLength: 14)

                Text(DurationFormatter.compactName(for: duration))
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(isCustom ? "CUSTOM" : "TAP TO START")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(accent.opacity(0.9))
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.16), AppTheme.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Start \(DurationFormatter.timerName(for: duration))")
    }
}
