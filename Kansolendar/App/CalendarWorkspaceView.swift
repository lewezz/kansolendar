import AppKit
import KansolendarCore
import KansolendarStorage
import SwiftUI

struct CalendarWorkspaceView: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: VaultViewModel
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppAccent.storageKey) private var accent = AppAccent.cyan.rawValue
    @AppStorage(AppFont.storageKey) private var font = AppFont.system.rawValue
    @State private var selectedCalendarID: UUID?
    @State private var editorEvent: Event?
    @State private var isPresentingEventEditor = false
    @State private var isPresentingCalendarEditor = false
    @State private var eventPendingDeletion: Event?
    @State private var calendarPendingDeletion: LocalCalendar?
    @State private var searchText = ""
    @State private var selectedDate = CivilDate.localToday
    @State private var displayedMonth = CalendarMonth(containing: CivilDate.localToday)
    @State private var viewMode: CalendarViewMode = .month
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Explicit text avoids the native toolbar automatically reducing Labels to icons.
    private func toolbarLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).accessibilityHidden(true)
            Text(title)
        }
        .padding(.horizontal, 6).padding(.vertical, 3).fixedSize()
        .accessibilityElement(children: .ignore).accessibilityLabel(title)
    }

    private var visibleEvents: [VaultEvent] {
        let calendarEvents = selectedCalendarID.map { calendarID in
            model.events.filter { $0.event.calendarID == calendarID }
        } ?? model.events
        let needle = EventSearch.normalized(searchText)
        guard !needle.isEmpty else { return calendarEvents }
        return calendarEvents.filter { EventSearch.normalized($0.event.title).contains(needle) }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedCalendarID) {
                Section {
                    ForEach(model.calendars) { calendar in
                        Label {
                            Text(calendar.name)
                        } icon: {
                            Circle()
                                .fill(calendar.color.swiftUIColor)
                                .frame(width: 9, height: 9)
                        }
                        .tag(calendar.id as UUID?)
                        .contextMenu {
                            Button(L10n.string("Delete Calendar"), role: .destructive) {
                                calendarPendingDeletion = calendar
                            }
                        }
                    }
                } header: {
                    Text(L10n.string("CALENDARS"))
                        .appTextFont(.caption2, weight: .bold)
                        .tracking(0.8)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 14) {
                    Button(L10n.string("New Calendar"), systemImage: "plus") {
                        isPresentingCalendarEditor = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(appAccentColor)
                    if let selectedCalendarID {
                        Button(L10n.string("Show All Events"), systemImage: "line.3.horizontal.decrease.circle.fill") {
                            self.selectedCalendarID = nil
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(appAccentColor)
                        .help(L10n.string("Clear calendar filter"))

                        if let calendar = model.calendars.first(where: { $0.id == selectedCalendarID }) {
                            Button(L10n.string("Delete Calendar"), systemImage: "trash", role: .destructive) {
                                calendarPendingDeletion = calendar
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 210)
        } detail: {
            calendarSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: AppWindowLayout.minimumWidth, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $searchText, placement: .toolbar, prompt: L10n.string("Search by title"))
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            // Keep the toggle beside the sidebar, including when it is hidden.
            ToolbarItem(placement: .navigation) {
                Button {
                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                } label: {
                    toolbarLabel(
                        columnVisibility == .detailOnly ? L10n.string("Show Sidebar") : L10n.string("Hide Sidebar"),
                        symbol: "sidebar.left"
                    )
                }
            }
            ToolbarItemGroup {
                Button {
                    guard let url = VaultFilePanel.chooseKansoDestination() else { return }
                    openWindow(id: "kanso-vault", value: url)
                } label: { toolbarLabel(L10n.string("New Vault"), symbol: "doc.badge.plus") }
                Button {
                    guard let url = VaultFilePanel.chooseKansoToOpen() else { return }
                    openWindow(id: "kanso-vault", value: url)
                } label: { toolbarLabel(L10n.string("Open Vault"), symbol: "folder") }

                Button {
                    editorEvent = nil
                    isPresentingEventEditor = true
                } label: { toolbarLabel(L10n.string("New Event"), symbol: "plus") }
                .disabled(model.calendars.isEmpty)
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    model.lock()
                } label: { toolbarLabel(L10n.string("Lock"), symbol: "lock") }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Menu {
                    Picker(L10n.string("Mode"), selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Label(option.localizedName, systemImage: option.systemImage)
                                .tag(option.rawValue)
                        }
                    }
                    Divider()
                    Picker(L10n.string("Accent Color"), selection: $accent) {
                        ForEach(AppAccent.allCases) { option in
                            Text(option.localizedName)
                                .tag(option.rawValue)
                        }
                    }
                    Divider()
                    Picker(L10n.string("Font"), selection: $font) {
                        ForEach(AppFont.allCases) { option in
                            Text(option.localizedName).tag(option.rawValue)
                        }
                    }
                } label: { toolbarLabel(L10n.string("Appearance"), symbol: selectedAppearance.systemImage) }
                .accessibilityLabel(L10n.string("Change appearance"))
            }
        }
        .labelStyle(.titleAndIcon)
        .task { await model.loadContent() }
        .sheet(isPresented: $isPresentingCalendarEditor) {
            CalendarEditorSheet(model: model)
        }
        .sheet(isPresented: $isPresentingEventEditor) {
            EventEditorSheet(
                model: model,
                event: editorEvent,
                preferredCalendarID: selectedCalendarID,
                preferredDate: selectedDate
            )
        }
        .alert(L10n.string("Delete this event?"), isPresented: deletionAlertBinding, presenting: eventPendingDeletion) { event in
            Button(L10n.string("Cancel"), role: .cancel) {}
            Button(L10n.string("Delete"), role: .destructive) {
                Task { _ = await model.deleteEvent(id: event.id) }
            }
        } message: { event in
            Text(L10n.format("“%@” will be removed from this vault.", event.title))
        }
        .alert(L10n.string("Delete this calendar?"), isPresented: calendarDeletionAlertBinding, presenting: calendarPendingDeletion) { calendar in
            Button(L10n.string("Cancel"), role: .cancel) {}
            Button(L10n.string("Delete Calendar"), role: .destructive) {
                Task {
                    if await model.deleteCalendar(id: calendar.id), selectedCalendarID == calendar.id {
                        selectedCalendarID = nil
                    }
                }
            }
        } message: { calendar in
            let count = model.events.filter { $0.event.calendarID == calendar.id }.count
            Text(L10n.format("“%@” and its %@ will be permanently deleted.", calendar.name, L10n.events(count)))
        }

    }

    private var selectedCalendar: LocalCalendar? {
        guard let selectedCalendarID else { return nil }
        return model.calendars.first { $0.id == selectedCalendarID }
    }

    @ViewBuilder
    private var calendarSurface: some View {
        if model.isLoadingContent {
            ProgressView(L10n.string("Loading private calendar…"))
        } else {
            VStack(spacing: 0) {
                CalendarModeBar(mode: $viewMode)
                Divider()
                Group {
                    switch viewMode {
                    case .day:
                        DayCalendarView(
                            events: visibleEvents,
                            calendars: model.calendars,
                            selectedDate: $selectedDate,
                            canCreateEvent: !model.calendars.isEmpty,
                            onCreateEvent: { presentEventEditor(on: $0) },
                            onEditEvent: editEvent,
                            onDeleteEvent: { eventPendingDeletion = $0 }
                        )
                    case .week:
                        WeekCalendarView(
                            events: visibleEvents,
                            calendars: model.calendars,
                            selectedDate: $selectedDate,
                            canCreateEvent: !model.calendars.isEmpty,
                            onCreateEvent: { presentEventEditor(on: $0) },
                            onEditEvent: editEvent
                        )
                    case .month:
                        MonthCalendarView(
                            events: visibleEvents,
                            calendars: model.calendars,
                            displayedMonth: $displayedMonth,
                            selectedDate: $selectedDate,
                            canCreateEvent: !model.calendars.isEmpty,
                            onCreateEvent: { presentEventEditor(on: $0) },
                            onEditEvent: editEvent,
                            onDeleteEvent: { eventPendingDeletion = $0 },
                            onMoveEvent: { eventID, date in
                                Task {
                                    if await model.moveEvent(id: eventID, to: date) {
                                        selectedDate = date
                                        displayedMonth = CalendarMonth(containing: date)
                                    }
                                }
                            }
                        )
                    case .year:
                        YearCalendarView(
                            events: visibleEvents,
                            selectedDate: $selectedDate,
                            canCreateEvent: !model.calendars.isEmpty,
                            onCreateEvent: { presentEventEditor(on: $0) }
                        )
                    }
                }
                .onChange(of: selectedDate) { _, date in
                    displayedMonth = CalendarMonth(containing: date)
                }
            }
            .overlay(alignment: .bottom) {
                if let message = model.message {
                    Text(L10n.string(message))
                        .appTextFont(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4).stroke(appAccentColor.opacity(0.45), lineWidth: 1)
                        }
                        .padding()
                        .accessibilityIdentifier("workspace-message")
                }
            }
        }
    }

    private func presentEventEditor(on date: CivilDate) {
        selectedDate = date
        editorEvent = nil
        isPresentingEventEditor = true
    }

    private func editEvent(_ event: Event) {
        editorEvent = event
        isPresentingEventEditor = true
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { eventPendingDeletion != nil },
            set: { if !$0 { eventPendingDeletion = nil } }
        )
    }

    private var calendarDeletionAlertBinding: Binding<Bool> {
        Binding(
            get: { calendarPendingDeletion != nil },
            set: { if !$0 { calendarPendingDeletion = nil } }
        )
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearance) ?? .system
    }
}

extension CalendarColor {
    var swatchImage: Image {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            nsColor.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return Image(nsImage: image).renderingMode(.original)
    }

    var swiftUIColor: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .gray: .gray
        }
    }

    private var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .gray: .systemGray
        }
    }

    @MainActor var localizedName: String {
        switch self {
        case .red: L10n.string("Red")
        case .orange: L10n.string("Orange")
        case .yellow: L10n.string("Yellow")
        case .green: L10n.string("Green")
        case .blue: L10n.string("Blue")
        case .purple: L10n.string("Purple")
        case .gray: L10n.string("Gray")
        }
    }
}
