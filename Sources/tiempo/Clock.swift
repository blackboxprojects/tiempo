import SwiftUI

/// Formatting rules recovered from the widget's clock_frame markup and clkwdt.js.
enum Clock {
    struct TimeParts {
        var hour: String
        var minute: String
        var ampm: String?
    }

    static func parts(_ date: Date, in tz: TimeZone, use24Hour: Bool) -> TimeParts {
        let c = tz.calendar.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0, m = String(format: "%02d", c.minute ?? 0)
        if use24Hour { return TimeParts(hour: String(h), minute: m, ampm: nil) }
        return TimeParts(hour: String(h % 12 == 0 ? 12 : h % 12), minute: m, ampm: h < 12 ? "am" : "pm")
    }

    static func menuBarTime(_ date: Date, in tz: TimeZone, use24Hour: Bool) -> String {
        let p = parts(date, in: tz, use24Hour: use24Hour)
        return "\(p.hour):\(p.minute)" + (p.ampm.map { " " + $0.uppercased() } ?? "")
    }

    /// "Sun, Nov 1"
    static func dateLabel(_ date: Date, in tz: TimeZone) -> String {
        var style = Date.FormatStyle(timeZone: tz).weekday(.abbreviated).month(.abbreviated).day()
        style.locale = Locale(identifier: "en_US")
        return date.formatted(style)
    }

    /// "GMT+0 (GMT) - 6 hours ahead": offset plus the difference from this Mac's time zone.
    static func detailLabel(_ city: City, at date: Date) -> String {
        let offset = offsetLabel(city.timeZone, at: date)
        guard !city.isCurrentLocation else { return offset }
        let diff = city.timeZone.secondsFromGMT(for: date) - TimeZone.autoupdatingCurrent.secondsFromGMT(for: date)
        guard diff != 0 else { return "\(offset) - same time" }
        // Whole hours as "6 hours", half and quarter hours as "5.5 hours" / "5.75 hours".
        let value = Double(abs(diff)) / 3600
        let hours = String(format: "%g", value) + (value == 1 ? " hour" : " hours")
        return "\(offset) - \(hours) \(diff > 0 ? "ahead" : "behind")"
    }

    /// "GMT+0 (GMT)", "GMT-5 (EST)", "GMT+5:30"
    static func offsetLabel(_ tz: TimeZone, at date: Date) -> String {
        let secs = tz.secondsFromGMT(for: date)
        let sign = secs < 0 ? "-" : "+"
        let h = abs(secs) / 3600, m = abs(secs) % 3600 / 60
        let offset = m == 0 ? "GMT\(sign)\(h)" : String(format: "GMT%@%d:%02d", sign, h, m)
        guard let abbr = tz.abbreviation(for: date), abbr == "GMT" || !abbr.hasPrefix("GMT") else { return offset }
        return "\(offset) (\(abbr))"
    }
}

/// The widget's tod_* classes, indexed by local hour.
enum DayPart {
    case midnight, night, morning, day, evening

    static func of(hour: Int) -> DayPart {
        switch hour {
        case 0: .midnight
        case 1...5, 22...23: .night
        case 6...7: .morning
        case 18...21: .evening
        default: .day
        }
    }

    /// Shades of the user's system accent color, darkest at night, so the strip follows
    /// System Settings → Appearance and light/dark mode.
    var fill: Color {
        switch self {
        case .midnight: .accentColor
        case .night: .accentColor.opacity(0.45)
        case .morning, .evening: .accentColor.opacity(0.18)
        case .day: .accentColor.opacity(0.06)
        }
    }

    var text: Color {
        switch self {
        case .midnight: .white
        case .night: .primary
        default: .secondary
        }
    }

    static let border = Color.accentColor.opacity(0.35)

    var name: String {
        switch self {
        case .midnight: "Midnight"
        case .night: "Night"
        case .morning: "Morning"
        case .day: "Day"
        case .evening: "Evening"
        }
    }
}

/// The panel's typeface, picked in the gear menu. Every option but JetBrains Mono ships with macOS.
enum FontChoice: String, Codable, CaseIterable {
    case jetBrainsMono, sfMono, sfPro, sfRounded, newYork, menlo

    /// Set by ClockStore; read by `Font.app` so every view uses the chosen face.
    static var current: FontChoice = .defaultChoice

    static var jetBrainsInstalled: Bool { NSFont(name: "JetBrainsMono-Regular", size: 12) != nil }
    static var defaultChoice: FontChoice { jetBrainsInstalled ? .jetBrainsMono : .sfMono }

    var title: String {
        switch self {
        case .jetBrainsMono: Self.jetBrainsInstalled ? "JetBrains Mono" : "JetBrains Mono (not installed)"
        case .sfMono: "SF Mono"
        case .sfPro: "SF Pro"
        case .sfRounded: "SF Pro Rounded"
        case .newYork: "New York"
        case .menlo: "Menlo"
        }
    }

    func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        switch self {
        case .jetBrainsMono where Self.jetBrainsInstalled: .custom("JetBrains Mono", size: size).weight(weight)
        case .jetBrainsMono, .sfMono: .system(size: size, weight: weight, design: .monospaced)
        case .sfPro: .system(size: size, weight: weight)
        case .sfRounded: .system(size: size, weight: weight, design: .rounded)
        case .newYork: .system(size: size, weight: weight, design: .serif)
        case .menlo: .custom("Menlo", size: size).weight(weight)
        }
    }

    /// AppKit equivalent of `font(_:_:)`, for measuring text.
    func nsFont(_ size: CGFloat, bold: Bool) -> NSFont {
        let weight: NSFont.Weight = bold ? .bold : .regular
        let mono = NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        let system = NSFont.systemFont(ofSize: size, weight: weight)
        func design(_ d: NSFontDescriptor.SystemDesign) -> NSFont {
            system.fontDescriptor.withDesign(d).flatMap { NSFont(descriptor: $0, size: size) } ?? system
        }
        switch self {
        case .jetBrainsMono: return NSFont(name: bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size) ?? mono
        case .sfMono: return mono
        case .sfPro: return system
        case .sfRounded: return design(.rounded)
        case .newYork: return design(.serif)
        case .menlo: return NSFont(name: bold ? "Menlo-Bold" : "Menlo-Regular", size: size) ?? mono
        }
    }
}

/// Light, dark, or follow the system setting.
enum AppearanceChoice: String, Codable, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Applies to the whole app, panel and menus alike.
    func apply() {
        NSApplication.shared.appearance = switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

extension Font {
    /// The panel font in the user's chosen face.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        FontChoice.current.font(size, weight)
    }

    /// Rendered width of `text` in the chosen face, for sizing the name column.
    static func textWidth(_ text: String, size: CGFloat, bold: Bool) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: FontChoice.current.nsFont(size, bold: bold)]).width)
    }
}
