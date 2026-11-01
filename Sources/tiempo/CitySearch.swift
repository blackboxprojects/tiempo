import SwiftUI

/// One searchable entry per system time zone, named after its city component.
private struct ZoneEntry: Identifiable {
    let id: String
    let city: String
    let region: String
    let zoneName: String
    let searchText: String

    static let all: [ZoneEntry] = (TimeZone.knownTimeZoneIdentifiers + ["UTC"]).compactMap { id in
        guard let tz = TimeZone(identifier: id) else { return nil }
        let parts = id.split(separator: "/")
        let city = (parts.last.map(String.init) ?? id).replacingOccurrences(of: "_", with: " ")
        let region = parts.count > 1 ? parts.dropLast().joined(separator: " / ").replacingOccurrences(of: "_", with: " ") : ""
        let zoneName = tz.localizedName(for: .generic, locale: Locale(identifier: "en_US")) ?? ""
        let abbr = tz.abbreviation() ?? ""
        return ZoneEntry(id: id, city: city, region: region, zoneName: zoneName,
                         searchText: [city, region, zoneName, abbr, id].joined(separator: " ").lowercased())
    }
    .sorted { $0.city < $1.city }
}

struct CitySearch: View {
    @Environment(ClockStore.self) private var store
    private let resultHeight: CGFloat = 34
    @State private var query: String
    @FocusState private var focused: Bool
    let done: () -> Void

    init(initialQuery: String = "", done: @escaping () -> Void) {
        _query = State(initialValue: initialQuery)
        self.done = done
    }

    private var matches: [ZoneEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return Array(ZoneEntry.all.filter { $0.searchText.contains(q) }.prefix(40))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Search city or time zone (e.g. Tokyo, PST)", text: $query).font(.app(11))
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { if let first = matches.first { add(first) } }

            if !matches.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(matches) { entry in
                            Button { add(entry) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(entry.city).font(.app(12, .semibold))
                                        Text([entry.region, entry.zoneName].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.app(9)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(Clock.menuBarTime(store.now, in: TimeZone(identifier: entry.id)!, use24Hour: store.use24Hour))
                                        .font(.app(11)).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 4)
                                .frame(height: resultHeight)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                // Explicit height: the menu bar window sizes to fit, which can collapse a scroll view.
                .frame(height: min(CGFloat(matches.count), 6) * resultHeight)
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 3))
        .onAppear { focused = true }
    }

    private func add(_ entry: ZoneEntry) {
        store.add(name: entry.city, timeZoneID: entry.id)
        done()
    }
}
