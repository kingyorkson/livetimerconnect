import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        iCloudSection
                        notificationsSection
                        liveActivitySection
                        deviceSection
                        aboutSection
                        resetButton
                    }
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Clear everything?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    model.clearEverything()
                }
            } message: {
                Text("This removes every timer, quick timer, and alarm from this device and your other devices on the same iCloud account.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SETTINGS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.textSecondary)

                Text("Settings")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Sync, sound, widgets, and alerts.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            SyncStatusPill(status: model.sync.status)
        }
    }

    private var iCloudSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("iCloud", subtitle: "One timer list for every device.")

            GlassCard {
                VStack(alignment: .leading, spacing: 15) {
                    InfoRow(
                        icon: model.sync.isAvailable ? "icloud.fill" : "icloud.slash",
                        title: model.sync.isAvailable ? "iCloud connected" : "iCloud unavailable",
                        detail: model.sync.status.detailText,
                        tint: syncTint
                    )

                    HStack(spacing: 8) {
                        if let lastSynced = model.sync.lastSyncedAt {
                            Text("Last activity \(lastSynced.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.textTertiary)
                        }

                        Spacer()

                        SettingsActionButton(
                            title: "Sync Now",
                            icon: "arrow.triangle.2.circlepath",
                            tint: AppTheme.orange
                        ) {
                            model.syncNow()
                        }
                    }

                    Divider()
                        .overlay(AppTheme.stroke)

                    Text("Start a timer on your iPhone and it appears on your iPad automatically. Both devices need to be signed in to the same Apple ID with iCloud Drive available.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Notifications & Sound", subtitle: "The end message, the loud ding, and Do Not Disturb.")

            GlassCard {
                VStack(alignment: .leading, spacing: 15) {
                    InfoRow(
                        icon: model.notificationsAuthorized ? "bell.badge.fill" : "bell.slash.fill",
                        title: model.notificationsAuthorized ? "Notifications allowed" : "Notifications are off",
                        detail: notificationDetail,
                        tint: model.notificationsAuthorized ? AppTheme.green : AppTheme.orange
                    )

                    Divider()
                        .overlay(AppTheme.stroke)

                    InfoRow(
                        icon: model.criticalAlertsEnabled ? "exclamationmark.shield.fill" : "exclamationmark.triangle.fill",
                        title: model.criticalAlertsEnabled ? "Critical alerts allowed" : "Critical alerts not available",
                        detail: criticalAlertDetail,
                        tint: model.criticalAlertsEnabled ? AppTheme.green : AppTheme.orange
                    )

                    HStack(spacing: 10) {
                        SettingsActionButton(
                            title: model.notificationStatus == .denied ? "Open Settings" : "Enable",
                            icon: model.notificationStatus == .denied ? "gearshape.fill" : "bell.fill",
                            tint: AppTheme.blue
                        ) {
                            if model.notificationStatus == .denied {
                                model.openSystemSettings()
                            } else {
                                model.requestNotifications()
                                model.showToast("Notification permission requested")
                            }
                        }

                        SettingsActionButton(
                            title: "Test Ding",
                            icon: "speaker.wave.3.fill",
                            tint: AppTheme.orange
                        ) {
                            model.playSoundPreview()
                            model.showToast("Playing the loud ding")
                        }
                    }
                }
            }
        }
    }

    private var liveActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Live Activities", subtitle: "Running timers on the Lock Screen.")

            GlassCard {
                VStack(alignment: .leading, spacing: 15) {
                    InfoRow(
                        icon: model.liveActivitiesEnabled ? "rectangle.topthird.inset.filled" : "rectangle.slash",
                        title: model.liveActivitiesEnabled ? "Live Activities enabled" : "Live Activities are off",
                        detail: model.liveActivitiesEnabled
                            ? "Running timers show their countdown, pause, and stop controls on the Lock Screen and in the Dynamic Island."
                            : "Turn on Live Activities for Live Timer Connect in iOS Settings to see running timers on the Lock Screen.",
                        tint: model.liveActivitiesEnabled ? AppTheme.green : AppTheme.orange
                    )

                    if !model.liveActivitiesEnabled {
                        SettingsActionButton(
                            title: "Open Settings",
                            icon: "gearshape.fill",
                            tint: AppTheme.orange
                        ) {
                            model.openSystemSettings()
                        }
                    }

                    Divider()
                        .overlay(AppTheme.stroke)

                    HStack(spacing: 8) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("Alarms never use Live Activities. They ring with notifications and offer Stop and Snooze 9 minutes.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Device", subtitle: "This copy of Live Timer Connect.")

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    InfoRow(
                        icon: "ipad.and.iphone",
                        title: model.deviceName,
                        detail: "iPhone + iPad app · iOS 17 or later",
                        tint: AppTheme.purple
                    )

                    Text("Timers and alarms use your private iCloud key-value store. No account is created and no data is sent to a server owned by this app.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("About", subtitle: "Live Timer Connect")

            GlassCard {
                VStack(alignment: .leading, spacing: 13) {
                    InfoRow(
                        icon: "timer",
                        title: "Live Timer Connect \(model.appVersion)",
                        detail: "Timers, alarms, iCloud sync, Live Activities, widgets, and a loud custom ding.",
                        tint: AppTheme.orange
                    )

                    Link(destination: AppConstants.repositoryURL) {
                        HStack(spacing: 7) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("View the project on GitHub")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.blue)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(AppTheme.blue.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showingResetAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Clear All Timers & Alarms")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(AppTheme.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.red.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.red.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var syncTint: Color {
        switch model.sync.status {
        case .synced:
            return AppTheme.green
        case .error:
            return AppTheme.red
        case .unavailable:
            return AppTheme.orange
        case .checking, .syncing:
            return AppTheme.blue
        }
    }

    private var notificationDetail: String {
        switch model.notificationStatus {
        case .authorized:
            return "Timers and alarms send an end message and play the custom ding. Critical alerts add a full-volume ring that can pierce Do Not Disturb."
        case .provisional:
            return "Quiet notifications are allowed. Open Settings to make them prominent."
        case .ephemeral:
            return "Temporary notification permission is active."
        case .denied:
            return "Allow notifications in iOS Settings to hear the ding and see the end message."
        case .notDetermined:
            return "Permission has not been requested yet."
        @unknown default:
            return "Notification permission status is unknown."
        }
    }

    private var criticalAlertDetail: String {
        if model.criticalAlertsEnabled {
            return "Timers and alarms can bypass Do Not Disturb, silent mode, and the mute switch."
        }
        return "Critical alerts need Apple's restricted entitlement. A sideloaded build can inject com.apple.developer.usernotifications.critical-alerts. As a fallback, add Live Timer Connect to Settings > Focus > Do Not Disturb > Allowed Apps."
    }
}

private struct SettingsActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.11))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
