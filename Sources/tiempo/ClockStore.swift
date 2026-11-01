import Foundation
import Observation
import ServiceManagement

struct City: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// nil means "this Mac's time zone" (the widget's "Your Time" row).
    var timeZoneID: String?

    var timeZone: TimeZone {
        timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
    }

    var isCurrentLocation: Bool { timeZoneID == nil }

    /// City part of this Mac's time zone, e.g. "Chicago".
    static var currentCityName: String {
        let id = TimeZone.autoupdatingCurrent.identifier
        return id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
    }

    /// The local row reads "Current Location (Chicago)", named from this Mac's time zone.
    var displayName: String {
        isCurrentLocation ? "Current Location (\(Self.currentCityName))" : name
    }
}

enum SortMode: String, Codable, CaseIterable {
    case manual, westToEast, eastToWest

    var title: String {
        switch self {
        case .manual: "Manual (drag to reorder)"
        case .westToEast: "Time Zone, West to East"
        case .eastToWest: "Time Zone, East to West"
        }
    }
}

private struct Settings: Codable {
    var cities: [City]
    var use24Hour: Bool
    var hoursShown: Int
    var menuBarCityID: UUID?
    var homeCityID: UUID?
    var sortMode: SortMode?
    var fontChoice: FontChoice?
    var appearance: AppearanceChoice?
}

@MainActor @Observable
final class ClockStore {
    var cities: [City] { didSet { save() } }
    var use24Hour: Bool { didSet { save() } }
    var hoursShown: Int { didSet { save(); pinnedColumn = nil } }
    var menuBarCityID: UUID? { didSet { save() } }
    /// The city whose hours the strip aligns to (the widget's `is_home` location).
    var homeCityID: UUID? { didSet { save() } }
    var sortMode: SortMode { didSet { save() } }
    var fontChoice: FontChoice { didSet { FontChoice.current = fontChoice; save() } }
    var appearance: AppearanceChoice { didSet { appearance.apply(); save() } }

    private(set) var now = Date()
    private(set) var colonVisible = true
    /// Column under the pointer, and column the user clicked; both index into `columns`.
    var hoverColumn: Int?
    var pinnedColumn: Int?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let defaultsKey = "settings.v1"

    init() {
        // Settings saved under the app's earlier name (bundle id local.timezona) carry over once.
        let saved = UserDefaults.standard.data(forKey: defaultsKey)
            ?? UserDefaults(suiteName: "local.timezona")?.data(forKey: defaultsKey)
        if let data = saved,
           let s = try? JSONDecoder().decode(Settings.self, from: data), !s.cities.isEmpty {
            cities = s.cities
            use24Hour = s.use24Hour
            hoursShown = s.hoursShown
            menuBarCityID = s.menuBarCityID
            homeCityID = s.homeCityID ?? s.cities.first?.id
            sortMode = s.sortMode ?? .manual
            fontChoice = s.fontChoice ?? .defaultChoice
            appearance = s.appearance ?? .system
        } else {
            // Mirrors the embedded widget: London (h=2643743) as home, then the viewer's own zone.
            let london = City(name: "London", timeZoneID: "Europe/London")
            cities = [london, City(name: "Current Location", timeZoneID: nil)]
            use24Hour = false
            hoursShown = 5
            menuBarCityID = nil
            homeCityID = london.id
            sortMode = .manual
            fontChoice = .defaultChoice
            appearance = .system
        }
        FontChoice.current = fontChoice
        appearance.apply()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        now = Date()
        colonVisible.toggle()
    }

    private func save() {
        let s = Settings(cities: cities, use24Hour: use24Hour, hoursShown: hoursShown, menuBarCityID: menuBarCityID,
                         homeCityID: homeCityID, sortMode: sortMode, fontChoice: fontChoice, appearance: appearance)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    // MARK: Hour strip

    /// The widget shows 1 hour before the current one and 3 after; keep that ratio when widened.
    var hoursBefore: Int { max(1, (hoursShown - 1) / 4) }

    /// Start instants of each strip column, aligned to the home city's hour boundaries.
    var columns: [Date] {
        let home = homeCity?.timeZone ?? .autoupdatingCurrent
        let start = home.calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return (0..<hoursShown).map { start.addingTimeInterval(Double($0 - hoursBefore) * 3600) }
    }

    var focusedColumn: Int { hoverColumn ?? pinnedColumn ?? hoursBefore }

    /// The instant the time column shows: live time, or the start of the focused hour.
    var displayedDate: Date {
        let i = focusedColumn
        return i == hoursBefore ? now : columns[i]
    }

    var showingLiveTime: Bool { focusedColumn == hoursBefore }

    // MARK: City list

    var menuBarCity: City? { cities.first { $0.id == menuBarCityID } }
    var homeCity: City? { cities.first { $0.id == homeCityID } ?? cities.first }

    /// Rows in display order: the saved manual order, or by current UTC offset.
    var sortedCities: [City] {
        guard sortMode != .manual else { return cities }
        let sorted = cities.enumerated().sorted { a, b in
            let oa = a.element.timeZone.secondsFromGMT(for: now), ob = b.element.timeZone.secondsFromGMT(for: now)
            return oa != ob ? oa < ob : a.offset < b.offset
        }.map(\.element)
        return sortMode == .westToEast ? sorted : sorted.reversed()
    }

    func add(name: String, timeZoneID: String) {
        cities.append(City(name: name, timeZoneID: timeZoneID))
    }

    func remove(_ city: City) {
        guard cities.count > 1 else { return }
        cities.removeAll { $0.id == city.id }
        if menuBarCityID == city.id { menuBarCityID = nil }
        if homeCityID == city.id { homeCityID = cities.first?.id }
    }

    /// Moves `id` just before or after `targetID`. A drag while sorted switches to manual,
    /// starting from the order on screen so nothing jumps.
    func move(_ id: UUID, relativeTo targetID: UUID, after: Bool) {
        if sortMode != .manual {
            cities = sortedCities
            sortMode = .manual
        }
        guard id != targetID, let from = cities.firstIndex(where: { $0.id == id }) else { return }
        var reordered = cities
        let moving = reordered.remove(at: from)
        guard let target = reordered.firstIndex(where: { $0.id == targetID }) else { return }
        reordered.insert(moving, at: after ? target + 1 : target)
        cities = reordered
    }

    /// Moves `id` into gap `gap` (0...count) of the on-screen order.
    func move(_ id: UUID, toGap gap: Int) {
        let order = sortedCities
        guard let from = order.firstIndex(where: { $0.id == id }), gap != from, gap != from + 1 else { return }
        if gap < order.count {
            move(id, relativeTo: order[gap].id, after: false)
        } else if let last = order.last {
            move(id, relativeTo: last.id, after: true)
        }
    }

    func move(_ city: City, by delta: Int) {
        let order = sortedCities
        guard let i = order.firstIndex(of: city), order.indices.contains(i + delta) else { return }
        move(city.id, relativeTo: order[i + delta].id, after: delta > 0)
    }

    func makeHome(_ city: City) {
        homeCityID = city.id
    }

    // MARK: Launch at login (works only when run from the .app bundle)

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login change failed: \(error)")
            }
        }
    }
}

extension TimeZone {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = self
        return c
    }
}
