import SwiftUI
import UniformTypeIdentifiers

private let cellWidth: CGFloat = 28

/// The current-location row is taller because its name wraps onto two lines.
private func rowHeight(for city: City) -> CGFloat {
    city.isCurrentLocation ? 56 : 44
}

/// The half-row a drag is over, and the gap between rows (0...count) it inserts into.
/// Bottom of row i and top of row i+1 share a gap, so the bar stays put crossing between them.
private struct DropZone: Equatable {
    var rowID: UUID
    var lowerHalf: Bool
    var gap: Int
}

struct ClockPanel: View {
    @Environment(ClockStore.self) private var store
    @State private var addingCity = false
    @State private var dropZone: DropZone?
    @State private var draggingID: UUID?

    /// The gap the bar marks, or nil when dropping there would leave the order unchanged.
    private func barGap(in cities: [City]) -> Int? {
        guard let zone = dropZone, let from = cities.firstIndex(where: { $0.id == draggingID }),
              zone.gap != from, zone.gap != from + 1 else { return nil }
        return zone.gap
    }

    var body: some View {
        let cities = store.sortedCities
        // Size the name column to the longest name line ("Current Location" wraps its city below).
        let names = cities.map { Font.textWidth($0.isCurrentLocation ? "Current Location" : $0.name, size: 12, bold: true) }
        let details = cities.map { Font.textWidth(Clock.detailLabel($0, at: store.displayedDate), size: 9, bold: false) }
        let nameWidth = min(220, max(100, (names + details).max() ?? 0) + 16)
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                        CityLabel(city: city, index: index, nameWidth: nameWidth, dropZone: $dropZone, draggingID: $draggingID)
                    }
                }
                HourStrip()
            }
            // Gray band across the current-location row, behind names, times and the strip.
            .background(alignment: .top) {
                RowLayer(cities: cities) { city in
                    Rectangle().fill(city.isCurrentLocation ? Color.gray.opacity(0.18) : .clear)
                }
                .padding(.leading, -10)
                .padding(.trailing, -6)
            }
            // Insertion bar showing where a dragged city will land.
            .overlay(alignment: .topLeading) {
                if let gap = barGap(in: cities) {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                        .offset(y: cities.prefix(gap).map(rowHeight(for:)).reduce(0, +) - 1.5)
                        .padding(.leading, -6)
                        .padding(.trailing, -2)
                        .allowsHitTesting(false)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))

            BottomBar(addingCity: $addingCity)

            if addingCity {
                CitySearch { addingCity = false }
            }
        }
        .padding(8)
        // Font.app reads a static, so rebuild the panel when the chosen face changes.
        .id(store.fontChoice)
        .background(RightEdgePinner())
    }
}

/// Keeps the menu bar panel flush with the right edge of the screen instead of centered
/// under the globe. MenuBarExtra re-places its window each time it opens or resizes,
/// so the pin is reapplied on every move and resize.
private struct RightEdgePinner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { PinView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class PinView: NSView {
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            pin(window)
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    if let window = self?.window { self?.pin(window) }
                })
            }
        }

        /// Pins the top edge just under the menu bar too, so the panel grows downward when
        /// cities are added instead of drifting or settling mid-screen.
        private func pin(_ window: NSWindow) {
            guard let screen = window.screen ?? NSScreen.main else { return }
            let visible = screen.visibleFrame
            let x = visible.maxX - window.frame.width - 6
            let y = visible.maxY - window.frame.height - 4
            if abs(window.frame.minX - x) > 0.5 || abs(window.frame.minY - y) > 0.5 {
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }
}

/// One stacked slot per city, each as tall as that city's row.
private struct RowLayer<Content: View>: View {
    let cities: [City]
    @ViewBuilder let content: (City) -> Content

    var body: some View {
        VStack(spacing: 0) {
            ForEach(cities) { city in
                content(city).frame(maxWidth: .infinity).frame(height: rowHeight(for: city))
            }
        }
    }
}

// MARK: Name + time columns

private struct CityLabel: View {
    @Environment(ClockStore.self) private var store
    let city: City
    let index: Int
    let nameWidth: CGFloat
    @Binding var dropZone: DropZone?
    @Binding var draggingID: UUID?

    var body: some View {
        let date = store.displayedDate
        let tz = city.timeZone
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if city.id == store.homeCity?.id {
                        Image(systemName: "house.fill").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    if city.isCurrentLocation {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Current Location").font(.app(12, .bold))
                            Text("(\(City.currentCityName))").font(.app(11)).foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                    } else {
                        Text(city.name).font(.app(12, .bold)).lineLimit(1)
                    }
                }
                Text(Clock.detailLabel(city, at: date)).font(.app(9)).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: nameWidth, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                TimeText(date: date, tz: tz)
                Text(Clock.dateLabel(date, in: tz)).font(.app(9)).foregroundStyle(.secondary)
            }
            .frame(width: 84, alignment: .trailing)
        }
        .frame(height: rowHeight(for: city))
        // Two invisible halves: the top inserts above this row, the bottom below it.
        .overlay {
            VStack(spacing: 0) {
                ForEach([false, true], id: \.self) { lower in
                    Color.clear
                        .contentShape(Rectangle())
                        .onDrop(of: [.text], delegate: GapDropDelegate(
                            zone: DropZone(rowID: city.id, lowerHalf: lower, gap: lower ? index + 1 : index),
                            store: store, current: $dropZone, draggingID: $draggingID))
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu { CityMenu(city: city) }
        // Drag a city's name between rows; the bar shows where it will land.
        .onDrag {
            draggingID = city.id
            return NSItemProvider(object: city.id.uuidString as NSString)
        }
    }
}

private struct GapDropDelegate: DropDelegate {
    let zone: DropZone
    let store: ClockStore
    @Binding var current: DropZone?
    @Binding var draggingID: UUID?

    func validateDrop(info: DropInfo) -> Bool { draggingID != nil }

    func dropEntered(info: DropInfo) { current = zone }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if current != zone { current = zone }
        return DropProposal(operation: .move)
    }

    // Enter for the next half can arrive before exit for this one, so only clear our own zone.
    func dropExited(info: DropInfo) {
        if current == zone { current = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { current = nil; draggingID = nil }
        guard let id = draggingID else { return false }
        store.move(id, toGap: zone.gap)
        return true
    }
}

private struct TimeText: View {
    @Environment(ClockStore.self) private var store
    let date: Date
    let tz: TimeZone

    var body: some View {
        let p = Clock.parts(date, in: tz, use24Hour: store.use24Hour)
        let live = store.showingLiveTime
        // The widget blinks the separator once a second via the `.blink .ts` class.
        let colon = live && !store.colonVisible ? Color.secondary.opacity(0.4) : (live ? Color.primary : Color.accentColor)
        (Text(p.hour) + Text(":").foregroundColor(colon) + Text(p.minute)
            + Text(p.ampm.map { " " + $0 } ?? "").font(.app(10)))
            .font(.app(15, .bold))
            .foregroundStyle(live ? Color.primary : Color.accentColor)
    }
}

private struct CityMenu: View {
    @Environment(ClockStore.self) private var store
    let city: City

    var body: some View {
        @Bindable var store = store
        Button("Show in Menu Bar") { store.menuBarCityID = city.id }
        Button("Make Home City") { store.makeHome(city) }
        Button("Move Up") { store.move(city, by: -1) }
        Button("Move Down") { store.move(city, by: 1) }
        Divider()
        Button("Remove", role: .destructive) { store.remove(city) }
            .disabled(store.cities.count < 2)
    }
}

// MARK: Hour strip

private struct HourStrip: View {
    @Environment(ClockStore.self) private var store

    var body: some View {
        let columns = store.columns
        HStack(spacing: 0) {
            ForEach(columns.indices, id: \.self) { i in
                VStack(spacing: 0) {
                    ForEach(store.sortedCities) { city in
                        HourCell(date: columns[i], tz: city.timeZone, use24Hour: store.use24Hour)
                            .frame(height: rowHeight(for: city))
                    }
                }
                .overlay {
                    if i == store.focusedColumn {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary, lineWidth: 2)
                            .padding(.vertical, 2)
                            .padding(.horizontal, -1)
                    }
                }
                .zIndex(i == store.focusedColumn ? 1 : 0)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { store.hoverColumn = i } else if store.hoverColumn == i { store.hoverColumn = nil }
                }
                .onTapGesture {
                    store.pinnedColumn = (i == store.hoursBefore || store.pinnedColumn == i) ? nil : i
                }
            }
        }
    }
}

private struct HourCell: View {
    let date: Date
    let tz: TimeZone
    let use24Hour: Bool

    var body: some View {
        let cal = tz.calendar
        let c = cal.dateComponents([.hour, .minute, .month, .day], from: date)
        let hour = c.hour ?? 0
        let part = DayPart.of(hour: hour)
        let nextHour = cal.component(.hour, from: date.addingTimeInterval(3600))
        let endsDay = nextHour < hour
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: part == .midnight ? 8 : 0,
            bottomLeadingRadius: part == .midnight ? 8 : 0,
            bottomTrailingRadius: endsDay ? 8 : 0,
            topTrailingRadius: endsDay ? 8 : 0
        )

        VStack(spacing: -1) {
            if part == .midnight {
                Text(Calendar.current.shortMonthSymbols[(c.month ?? 1) - 1].uppercased())
                    .font(.app(7, .semibold))
                Text(String(c.day ?? 1)).font(.app(12, .bold))
            } else {
                let p = Clock.parts(date, in: tz, use24Hour: use24Hour)
                let minutes = (c.minute ?? 0) == 0 ? "" : ":\(p.minute)"
                Text(p.hour).font(.app(12))
                Text(minutes + (p.ampm ?? "")).font(.app(7))
            }
        }
        .foregroundStyle(part.text)
        .frame(width: endsDay ? cellWidth - 1 : cellWidth, height: 30)
        .background(part.fill, in: shape)
        .overlay {
            VStack(spacing: 0) {
                Rectangle().frame(height: 1)
                Spacer(minLength: 0)
                Rectangle().frame(height: 1)
            }
            .foregroundStyle(DayPart.border)
            .clipShape(shape)
        }
        .padding(.trailing, endsDay ? 1 : 0)
        .help("\(part.name), \(Clock.dateLabel(date, in: tz))")
    }
}

// MARK: Bottom bar

private struct BottomBar: View {
    @Environment(ClockStore.self) private var store
    @Binding var addingCity: Bool

    var body: some View {
        @Bindable var store = store
        HStack(spacing: 6) {
            Text("tiempo").font(.app(9, .bold)).foregroundStyle(.secondary)

            if store.pinnedColumn != nil {
                Button("Now") { store.pinnedColumn = nil }
                    .buttonStyle(.plain).font(.app(9, .bold)).foregroundStyle(Color.accentColor)
            }

            Spacer()

            Button { addingCity.toggle() } label: {
                Label(addingCity ? "Done" : "Add City", systemImage: addingCity ? "xmark" : "plus")
                    .font(.app(10, .bold))
            }
            .buttonStyle(.plain).foregroundStyle(Color.accentColor).help("Search for a city to add")

            Menu {
                Picker("Sort", selection: $store.sortMode) {
                    ForEach(SortMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Font", selection: $store.fontChoice) {
                    ForEach(FontChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Appearance", selection: $store.appearance) {
                    ForEach(AppearanceChoice.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("Hours Shown", selection: $store.hoursShown) {
                    ForEach([5, 9, 13, 17, 24], id: \.self) { Text("\($0) hours").tag($0) }
                }
                Picker("Menu Bar", selection: $store.menuBarCityID) {
                    Text("Globe Only").tag(UUID?.none)
                    ForEach(store.cities) { Text($0.displayName).tag(Optional($0.id)) }
                }
                Toggle("Launch at Login", isOn: $store.launchAtLogin)
                Divider()
                Button("Quit tiempo") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(.secondary)

            FormatToggle(label: "AM", selected: !store.use24Hour) { store.use24Hour = false }
            FormatToggle(label: "24", selected: store.use24Hour) { store.use24Hour = true }
        }
        .padding(.horizontal, 2)
    }
}

private struct FormatToggle: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.app(9, .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .background(selected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }
}
