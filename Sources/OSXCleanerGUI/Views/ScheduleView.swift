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

        let infos = appState.schedulerService.listSchedules()
        schedules = infos.map { info in
            ScheduleItem(
                name: "\(info.frequency.capitalized) Cleanup",
                frequency: GUIScheduleFrequency(rawValue: info.frequency.capitalized) ?? .daily,
                level: CleanupLevel.from(string: info.level) ?? .normal,
                hour: parseHour(from: info.timeDescription),
                minute: parseMinute(from: info.timeDescription),
                weekday: parseWeekday(from: info.timeDescription),
                dayOfMonth: parseDay(from: info.timeDescription),
                isEnabled: info.enabled
            )
        }
    }

    private func toggleSchedule(_ schedule: ScheduleItem) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }

        do {
            let frequency = schedule.frequency.toBackendFrequency()
            if schedule.isEnabled {
                try appState.schedulerService.disableSchedule(frequency)
            } else {
                try appState.schedulerService.enableSchedule(frequency)
            }
            schedules[index].isEnabled.toggle()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func deleteSchedule(_ schedule: ScheduleItem) {
        do {
            let frequency = schedule.frequency.toBackendFrequency()
            try appState.schedulerService.removeSchedule(frequency)
            schedules.removeAll { $0.id == schedule.id }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    // MARK: - Parse Helpers

    private func parseHour(from timeDesc: String) -> Int {
        let components = timeDesc.components(separatedBy: ":")
        guard let hour = components.first, let hourInt = Int(hour) else { return 0 }
        return hourInt
    }

    private func parseMinute(from timeDesc: String) -> Int {
        let components = timeDesc.components(separatedBy: ":")
        guard components.count > 1 else { return 0 }
        let minutePart = components[1].prefix(2)
        return Int(minutePart) ?? 0
    }

    private func parseWeekday(from timeDesc: String) -> Weekday? {
        for weekday in Weekday.allCases {
            if timeDesc.contains(weekday.rawValue) {
                return weekday
            }
        }
        return nil
    }

    private func parseDay(from timeDesc: String) -> Int? {
        if let range = timeDesc.range(of: "on day ") {
            let dayPart = timeDesc[range.upperBound...]
            return Int(dayPart.prefix(2).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}

// MARK: - Supporting Types

struct ScheduleItem: Identifiable {
    let id = UUID()
    var name: String
    var frequency: GUIScheduleFrequency
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

/// GUI-specific schedule frequency that maps to backend ScheduleFrequency
enum GUIScheduleFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    func toBackendFrequency() -> ScheduleFrequency {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        }
    }
}

enum Weekday: String, CaseIterable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"

    var weekdayNumber: Int {
        switch self {
        case .sunday: return 0
        case .monday: return 1
        case .tuesday: return 2
        case .wednesday: return 3
        case .thursday: return 4
        case .friday: return 5
        case .saturday: return 6
        }
    }
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
    @EnvironmentObject private var appState: AppState

    @State private var name = ""
    @State private var frequency: GUIScheduleFrequency = .daily
    @State private var level: CleanupLevel = .light
    @State private var hour = 3
    @State private var minute = 0
    @State private var weekday: Weekday = .sunday
    @State private var dayOfMonth = 1
    @State private var errorMessage: String?

    let onAdd: (ScheduleItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Details") {
                    TextField("Name", text: $name)

                    Picker("Frequency", selection: $frequency) {
                        ForEach(GUIScheduleFrequency.allCases, id: \.self) { freq in
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

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
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
                        createSchedule()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func createSchedule() {
        do {
            let config = ScheduleConfig(
                frequency: frequency.toBackendFrequency(),
                level: level,
                hour: hour,
                minute: minute,
                weekday: frequency == .weekly ? weekday.weekdayNumber : nil,
                day: frequency == .monthly ? dayOfMonth : nil
            )

            try appState.schedulerService.createSchedule(config)
            try appState.schedulerService.enableSchedule(frequency.toBackendFrequency())

            let newSchedule = ScheduleItem(
                name: name.isEmpty ? "\(frequency.rawValue) Cleanup" : name,
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(AppState())
}
