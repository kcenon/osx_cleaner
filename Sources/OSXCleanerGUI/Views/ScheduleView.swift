// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

import SwiftUI
import OSXCleanerKit

/// Schedule view for managing automated cleanup schedules
struct ScheduleView: View {
    @EnvironmentObject private var appState: AppState

    @State private var schedules: [ScheduleItem] = []
    @State private var showAddSheet = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading schedules...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if schedules.isEmpty {
                emptyStateView
            } else {
                scheduleList
            }
        }
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Schedule", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddScheduleSheet { newSchedule in
                schedules.append(newSchedule)
            }
        }
        .task {
            await loadSchedules()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Schedules", systemImage: "calendar.badge.clock")
        } description: {
            Text("Set up automated cleanup schedules to keep your Mac running smoothly.")
        } actions: {
            Button("Add Schedule") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Schedule List

    private var scheduleList: some View {
        List {
            ForEach(schedules) { schedule in
                ScheduleRow(schedule: schedule) {
                    toggleSchedule(schedule)
                } onDelete: {
                    deleteSchedule(schedule)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Actions

    private func loadSchedules() async {
        isLoading = true
        defer { isLoading = false }

        // TODO: Load actual schedules from SchedulerService
        // Simulated data for now
        schedules = [
            ScheduleItem(
                name: "Daily Light Cleanup",
                frequency: .daily,
                level: .light,
                hour: 3,
                minute: 0,
                isEnabled: true
            ),
            ScheduleItem(
                name: "Weekly Normal Cleanup",
                frequency: .weekly,
                level: .normal,
                hour: 2,
                minute: 30,
                weekday: .sunday,
                isEnabled: false
            )
        ]
    }

    private func toggleSchedule(_ schedule: ScheduleItem) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index].isEnabled.toggle()
            // TODO: Update actual schedule via SchedulerService
        }
    }

    private func deleteSchedule(_ schedule: ScheduleItem) {
        schedules.removeAll { $0.id == schedule.id }
        // TODO: Delete actual schedule via SchedulerService
    }
}

// MARK: - Supporting Types

struct ScheduleItem: Identifiable {
    let id = UUID()
    var name: String
    var frequency: ScheduleFrequency
    var level: CleanupLevel
    var hour: Int
    var minute: Int
    var weekday: Weekday?
    var dayOfMonth: Int?
    var isEnabled: Bool

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var scheduleDescription: String {
        switch frequency {
        case .daily:
            return "Daily at \(timeString)"
        case .weekly:
            return "\(weekday?.rawValue ?? "Sunday") at \(timeString)"
        case .monthly:
            return "Day \(dayOfMonth ?? 1) at \(timeString)"
        }
    }
}

enum ScheduleFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum Weekday: String, CaseIterable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let schedule: ScheduleItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(schedule.scheduleDescription, systemImage: "clock")
                    Text("•")
                    Label(schedule.level.displayName, systemImage: "sparkles")
                        .foregroundStyle(schedule.level.color)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Add Schedule Sheet

struct AddScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var frequency: ScheduleFrequency = .daily
    @State private var level: CleanupLevel = .light
    @State private var hour = 3
    @State private var minute = 0
    @State private var weekday: Weekday = .sunday
    @State private var dayOfMonth = 1

    let onAdd: (ScheduleItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Details") {
                    TextField("Name", text: $name)

                    Picker("Frequency", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    Picker("Cleanup Level", selection: $level) {
                        ForEach(CleanupLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section("Time") {
                    Stepper("Hour: \(hour)", value: $hour, in: 0...23)
                    Stepper("Minute: \(minute)", value: $minute, in: 0...59)

                    if frequency == .weekly {
                        Picker("Weekday", selection: $weekday) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                Text(day.rawValue).tag(day)
                            }
                        }
                    }

                    if frequency == .monthly {
                        Stepper("Day of Month: \(dayOfMonth)", value: $dayOfMonth, in: 1...28)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newSchedule = ScheduleItem(
                            name: name.isEmpty ? "Cleanup Schedule" : name,
                            frequency: frequency,
                            level: level,
                            hour: hour,
                            minute: minute,
                            weekday: frequency == .weekly ? weekday : nil,
                            dayOfMonth: frequency == .monthly ? dayOfMonth : nil,
                            isEnabled: true
                        )
                        onAdd(newSchedule)
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }
}

#Preview {
    ScheduleView()
        .environmentObject(AppState())
}
