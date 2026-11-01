import SwiftUI

struct AddQuickTimerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var days = 0
    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0

    private var totalDuration: TimeInterval {
        TimeInterval(days * 86_400 + hours * 3_600 + minutes * 60 + seconds)
    }

    private var isValid: Bool {
        totalDuration >= 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        preview
                        pickerCard
                        hint
                    }
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Add Quick Timer")
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
                    Button("Done") {
                        model.addQuickTimer(duration: totalDuration)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(isValid ? AppTheme.orange : AppTheme.textTertiary)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var preview: some View {
        VStack(spacing: 8) {
            Text(DurationFormatter.clockString(totalDuration))
                .font(.system(size: 46, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(DurationFormatter.timerName(for: totalDuration))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("This will appear as a one-tap quick timer.")
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
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                wheelColumn(title: "DAYS", selection: $days, values: Array(0...29))
                wheelColumn(title: "HOURS", selection: $hours, values: Array(0...23))
                wheelColumn(title: "MINUTES", selection: $minutes, values: Array(0...59))
                wheelColumn(title: "SECONDS", selection: $seconds, values: Array(0...59))
            }
            .frame(height: 170)

            Text("Maximum 29 days, 23 hours, 59 minutes, 59 seconds")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
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
            .frame(height: 138)
            .clipped()

            Text(title)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var hint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.blue)

            Text("Slide the wheels to choose a duration. After you tap Done, the new preset is available on all of your devices.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.15), lineWidth: 1)
        )
    }
}
