import SwiftUI

@main
struct TiempoApp: App {
    @State private var store = ClockStore()

    var body: some Scene {
        MenuBarExtra {
            ClockPanel()
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The SF Symbols globe at 17pt, a little larger than the menu bar default. As a template
/// image macOS draws it black or white to match the menu bar.
private let globeIcon: NSImage = {
    let base = NSImage(systemSymbolName: "globe", accessibilityDescription: "tiempo") ?? NSImage()
    let image = base.withSymbolConfiguration(.init(pointSize: 17, weight: .regular)) ?? base
    image.isTemplate = true
    return image
}()

/// Wireframe globe, plus the chosen city's time when one is picked in the gear menu.
struct MenuBarLabel: View {
    let store: ClockStore

    var body: some View {
        Image(nsImage: globeIcon)
        if let city = store.menuBarCity {
            Text("\(city.displayName) \(Clock.menuBarTime(store.now, in: city.timeZone, use24Hour: store.use24Hour))")
        }
    }
}
