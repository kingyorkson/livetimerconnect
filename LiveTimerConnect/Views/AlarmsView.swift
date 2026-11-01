import SwiftUI

struct AlarmsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAddAlarm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        alarmSection
                        addButton
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
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView()
                    .environmentObject(model)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(AppTheme.orange)
                        .frame(width: 7, height: 7)
                        .shadow(color: AppTheme.orange.opacity(0.8), radius: 5)

                    Text("LOUD DING · NO LIVE ACTIVITY")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("Alarms")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Set any hour and minute across the whole day.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 4)

            SyncStatusPill(status: model.sync.status)
        }
    }

    private var alarmSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionHeading(
                "Your Alarms",
                subtitle: model.alarms.isEmpty
                    ? "No alarms yet."
                    : "\(model.alarms.filter(\.isEnabled).count) on · \(model.alarms.count) total"
            )

            if model.alarms.isEmpty {
                EmptyStateCard(
                    icon: "alarm",
                    title: "Never miss a moment",
                    message: "Add an alarm from 12 AM to 12 AM. It rings on every device with your custom ding."
                )
            } else {
                ForEach(model.alarms) { alarm in
                    AlarmRow(alarm: alarm)
                        .contextMenu {
                            Button(role: .destructive) {
                                model.deleteAlarm(alarm.id)
                            } label: {
                                Label("Delete Alarm", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            showingAddAlarm = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .black))
                Text("Add Alarm")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.orange, Color(red: 1.0, green: 0.42, blue: 0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: AppTheme.orange.opacity(0.28), radius: 18, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct AlarmRow: View {
    @EnvironmentObject private var model: AppModel
    let alarm: AlarmItem

    private var tint: Color {
        alarm.isEnabled ? AppTheme.orange : AppTheme.textTertiary
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(alarm.timeText)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(alarm.isEnabled ? .white : AppTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(alarm.displayLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(alarm.repeatText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .foregroundStyle(tint)
            }

            Spacer(minLength: 4)

            Toggle(
                "",
                isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { model.setAlarmEnabled(alarm.id, enabled: $0) }
                )
            )
            .labelsHidden()
            .tint(AppTheme.orange)
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(alarm.isEnabled ? 0.11 : 0.035), AppTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .stroke(tint.opacity(alarm.isEnabled ? 0.17 : 0.06), lineWidth: 1)
        )
        .opacity(alarm.isEnabled ? 1 : 0.75)
    }
}
