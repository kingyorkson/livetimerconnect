import SwiftUI

struct AddAlarmView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var hour: Int
    @State private var minute: Int
    @State private var isPM: Bool
    @State private var label = "Alarm"
    @State private var repeatsDaily = true

    init() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let currentHour = components.hour ?? 7
        _hour = State(initialValue: currentHour % 12 == 0 ? 12 : currentHour % 12)
        _minute = State(initialValue: components.minute ?? 0)
        _isPM = State(initialValue: currentHour >= 12)
    }

    private var hour24: Int {
        (hour % 12) + (isPM ? 12 : 0)
    }

    private var previewDate: Date {
        var components = DateComponents()
        components.hour = hour24
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }

    private var previewText: String {
        previewDate.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        preview
                        pickerCard
                        detailsCard
                        note
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.addAlarm(
                            hour: hour24,
                            minute: minute,
                            label: label,
                            repeatsDaily: repeatsDaily
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.orange)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var preview: some View {
        VStack(spacing: 6) {
            Text(previewText)
                .font(.system(size: 48, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alarm" : label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.orange)
                .lineLimit(1)

            Text(repeatsDaily ? "Rings every day" : "Rings once")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.orange.opacity(0.18), AppTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .stroke(AppTheme.orange.opacity(0.22), lineWidth: 1)
        )
    }

    private var pickerCard: some View {
        HStack(spacing: 0) {
            wheelColumn(title: "HOUR", selection: $hour, values: Array(1...12))
            wheelColumn(title: "MINUTE", selection: $minute, values: Array(0...59))
            amPMColumn
        }
        .frame(height: 185)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var amPMColumn: some View {
        VStack(spacing: 3) {
            Picker("Period", selection: $isPM) {
                Text("AM").tag(false)
                Text("PM").tag(true)
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 153)
            .clipped()

            Text("PERIOD")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func wheelColumn(
        title: String,
        selection: Binding<Int>,
        values: [Int]
    ) -> some View {
        VStack(spacing: 3) {
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text("\(value)")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 153)
            .clipped()

            Text(title)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailsCard: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LABEL")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textTertiary)

                TextField("Alarm", text: $label)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
            }

            Divider()
                .overlay(AppTheme.stroke)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Repeat every day")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Turn off to ring at the next occurrence only.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Toggle("", isOn: $repeatsDaily)
                    .labelsHidden()
                    .tint(AppTheme.orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.orange)

            Text("Alarms ring with the custom loud ding and offer Stop or Snooze 9 minutes. They never use Live Activities.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.orange.opacity(0.15), lineWidth: 1)
        )
    }
}
