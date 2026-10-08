import AppKit
import KansolendarCore
import SwiftUI

struct CalendarEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: VaultViewModel
    @State private var name = ""
    @State private var color: CalendarColor = .blue
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            EditorSheetHeader(
                title: L10n.string("New Calendar"),
                subtitle: L10n.string("Create a distinct private event channel."),
                systemImage: "calendar.badge.plus"
            )

            Divider()

            VStack(spacing: 16) {
                EditorSection(title: L10n.string("Identity"), systemImage: "textformat") {
                    EditorField(L10n.string("Name"), hint: L10n.string("For example: Personal, Work, or Travel")) {
                        TextField(L10n.string("Calendar name"), text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                EditorSection(title: L10n.string("Color"), systemImage: "paintpalette") {
                    Picker(L10n.string("Calendar color"), selection: $color) {
                        ForEach(CalendarColor.allCases, id: \.self) { option in
                            Label {
                                Text(option.localizedName)
                            } icon: {
                                option.swatchImage
                                    .accessibilityHidden(true)
                            }
                            .tag(option)
                        }
                    }

                    HStack(spacing: 12) {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendarPreviewName)
                                .appTextFont(.headline)
                            Text(L10n.string("Sidebar preview"))
                                .appTextFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(22)

            Divider()

            HStack {
                Spacer()
                Button(L10n.string("Cancel"), role: .cancel) { dismiss() }
                Button(L10n.string("Create")) {
                    isSaving = true
                    Task {
                        if await model.createCalendar(name: name, color: color) { dismiss() }
                        isSaving = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var calendarPreviewName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.string("Calendar name") : trimmed
    }
}

/// Form values stay local until validation and persistence succeed; cancelling discards the draft.
struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: VaultViewModel
    let event: Event?
    @State private var calendarID: UUID
    @State private var title: String
    @State private var notes: String
    @State private var location: String
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay: Bool
    @State private var isSaving = false

    init(model: VaultViewModel, event: Event?, preferredCalendarID: UUID?, preferredDate: CivilDate) {
        self.model = model
        self.event = event
        let initialCalendarID = event?.calendarID ?? preferredCalendarID ?? model.calendars.first?.id ?? UUID()
        _calendarID = State(initialValue: initialCalendarID)
        _title = State(initialValue: event?.title ?? "")
        _notes = State(initialValue: event?.notes ?? "")
        _location = State(initialValue: event?.location ?? "")
        let preferredStart = Calendar.autoupdatingCurrent.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: MonthCalendarView.foundationDate(preferredDate)
        ) ?? Date()
        let initialStart = event.map(EventDateAdapter.startDate(for:)) ?? preferredStart
        _start = State(initialValue: initialStart)
        _end = State(initialValue: event.map(EventDateAdapter.endDate(for:)) ?? initialStart.addingTimeInterval(3_600))
        _isAllDay = State(initialValue: event.map(EventDateAdapter.isAllDay) ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorSheetHeader(
                title: event == nil ? L10n.string("New Event") : L10n.string("Edit Event"),
                subtitle: event == nil ? L10n.string("Add an entry to your private timeline.") : L10n.string("Update this timeline entry."),
                systemImage: event == nil ? "calendar.badge.plus" : "calendar.badge.clock"
            )

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    EditorSection(title: L10n.string("Details"), systemImage: "text.alignleft") {
                        HStack(alignment: .top, spacing: 16) {
                            EditorField(L10n.string("Title"), hint: L10n.string("Describe the event briefly")) {
                                TextField(L10n.string("Event title"), text: $title)
                                    .textFieldStyle(.roundedBorder)
                            }

                            EditorField(L10n.string("Calendar")) {
                                Picker(L10n.string("Calendar"), selection: $calendarID) {
                                    ForEach(model.calendars) { calendar in
                                        Label {
                                            Text(calendar.name)
                                        } icon: {
                                            calendar.color.swatchImage
                                                .accessibilityHidden(true)
                                        }
                                        .tag(calendar.id)
                                    }
                                }
                                .labelsHidden()
                                .disabled(event != nil)
                            }
                            .frame(width: 220)
                        }
                    }

                    EditorSection(title: L10n.string("Schedule"), systemImage: "clock") {
                        Toggle(L10n.string("All-day event"), isOn: $isAllDay)

                        if !isAllDay {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L10n.string("START TIME"))
                                        .appTextFont(.caption, weight: .bold)
                                        .foregroundStyle(.secondary)
                                    TimeWheelPicker(selection: $start, accessibilityLabel: L10n.string("Start Time"))
                                }
                                .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L10n.string("END TIME"))
                                        .appTextFont(.caption, weight: .bold)
                                        .foregroundStyle(.secondary)
                                    TimeWheelPicker(selection: $end, accessibilityLabel: L10n.string("End Time"))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        Divider()

                        HStack(alignment: .top, spacing: 16) {
                            EditorField(L10n.string("Start Date")) {
                                DatePicker(
                                    L10n.string("Start Date"),
                                    selection: $start,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.field)
                                .labelsHidden()
                            }
                            EditorField(L10n.string("End Date")) {
                                DatePicker(
                                    L10n.string("End Date"),
                                    selection: $end,
                                    in: start...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.field)
                                .labelsHidden()
                            }
                        }
                    }

                    EditorSection(title: L10n.string("Optional Data"), systemImage: "info.circle") {
                        HStack(alignment: .top, spacing: 16) {
                            EditorField(L10n.string("Location")) {
                                TextField(L10n.string("Add location"), text: $location)
                                    .textFieldStyle(.roundedBorder)
                            }
                            EditorField(L10n.string("Notes")) {
                                TextField(L10n.string("Add notes"), text: $notes, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)
                            }
                        }
                    }
                }
                .padding(18)
            }

            Divider()

            HStack {
                Spacer()
                Button(L10n.string("Cancel"), role: .cancel) { dismiss() }
                Button(L10n.string("Save")) {
                    isSaving = true
                    Task {
                        if await model.saveEvent(
                            existing: event,
                            calendarID: calendarID,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes,
                            location: location,
                            start: start,
                            end: end,
                            isAllDay: isAllDay
                        ) { dismiss() }
                        isSaving = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start || isSaving)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 760, height: 580)
        .onChange(of: isAllDay) { _, enabled in
            guard enabled, Calendar.autoupdatingCurrent.isDate(start, inSameDayAs: end),
                  let nextDay = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: start) else { return }
            end = nextDay
        }
        .onChange(of: start) { _, newStart in
            guard end <= newStart else { return }
            let component: Calendar.Component = isAllDay ? .day : .hour
            end = Calendar.autoupdatingCurrent.date(byAdding: component, value: 1, to: newStart)
                ?? newStart.addingTimeInterval(isAllDay ? 86_400 : 3_600)
        }
    }

}

private struct TimeWheelPicker: View {
    @Environment(\.appAccentColor) private var accent
    @Binding var selection: Date
    let accessibilityLabel: String
    @State private var hour: Int?
    @State private var minute: Int?

    var body: some View {
        HStack(spacing: 8) {
            TimeWheelColumn(values: Array(0..<24), selection: $hour, accent: accent)
                .accessibilityLabel(L10n.format("%@ hour", accessibilityLabel))
            Text(":")
                .appTextFont(.title, weight: .bold)
                .foregroundStyle(accent)
            TimeWheelColumn(values: Array(0..<60), selection: $minute, accent: accent)
                .accessibilityLabel(L10n.format("%@ minute", accessibilityLabel))
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: syncFromSelection)
        .onChange(of: selection) { _, _ in syncFromSelection() }
        .onChange(of: hour) { _, _ in updateSelection() }
        .onChange(of: minute) { _, _ in updateSelection() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func syncFromSelection() {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: selection)
        hour = components.hour
        minute = components.minute
    }

    private func updateSelection() {
        guard let hour, let minute else { return }
        selection = Calendar.autoupdatingCurrent.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: selection
        ) ?? selection
    }
}

private struct TimeWheelColumn: View {
    let values: [Int]
    @Binding var selection: Int?
    let accent: Color

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { value in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) { selection = value }
                    } label: {
                        Text(String(format: "%02d", value))
                            .appTextFont(.title2, weight: selection == value ? .bold : .regular)
                            .foregroundStyle(selection == value ? accent : .secondary)
                            .frame(width: 62, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .id(value)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.vertical, 37, for: .scrollContent)
        .scrollPosition(id: $selection, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .frame(width: 66, height: 108)
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(accent.opacity(0.28), lineWidth: 1)
                .frame(height: 34)
                .allowsHitTesting(false)
        }
        .clipped()
    }
}

private struct EditorSheetHeader: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .appTextFont(size: 21, weight: .semibold)
                .foregroundStyle(appAccentColor)
                .frame(width: 42, height: 42)
                .background(appAccentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appTextFont(.title2, weight: .semibold)
                    .tracking(0.5)
                Text(subtitle)
                    .appTextFont(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
}

private struct EditorSection<Content: View>: View {
    @Environment(\.appAccentColor) private var appAccentColor
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(appAccentColor)
            }
            .appTextFont(.caption, weight: .bold)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
    }
}

private struct EditorField<Content: View>: View {
    let label: String
    let hint: String?
    @ViewBuilder let content: Content

    init(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .appTextFont(.subheadline, weight: .medium)
            content
            if let hint {
                Text(hint)
                    .appTextFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
