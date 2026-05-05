import Foundation

struct Thing: Identifiable, Equatable, Codable {
    let id: Int
    var name: String
    var date: String?     // ISO yyyy-MM-dd, optional
    var tags: [String]
    var starred: Bool
    var completed: Bool = false
    var completedAt: Date? = nil
}

enum DateUtil {
    private static var localCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    static func startOfToday() -> Date {
        localCalendar.startOfDay(for: Date())
    }

    static func fmtISO(_ d: Date) -> String {
        let comps = localCalendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 1, comps.day ?? 1)
    }

    static func parseISO(_ s: String) -> Date? {
        let parts = s.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        return localCalendar.date(from: comps)
    }

    static func daysFromToday(_ iso: String) -> Int {
        guard let d = parseISO(iso) else { return 0 }
        let t = startOfToday()
        let diff = localCalendar.dateComponents([.day], from: t, to: d).day ?? 0
        return diff
    }

    static func dayLabel(_ iso: String) -> String {
        let diff = daysFromToday(iso)
        if diff == 0 { return "Today" }
        if diff == 1 { return "Tomorrow" }
        if diff == -1 { return "Yesterday" }
        guard let d = parseISO(iso) else { return iso }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        if diff > 1 && diff < 7 {
            f.dateFormat = "EEEE"
            return f.string(from: d)
        }
        f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }

    static func dayMeta(_ iso: String) -> (weekday: String, day: Int, month: String, year: Int) {
        guard let d = parseISO(iso) else { return ("", 0, "", 0) }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE"
        let weekday = f.string(from: d).uppercased()
        f.dateFormat = "MMM"
        let month = f.string(from: d).uppercased()
        let comps = localCalendar.dateComponents([.day, .year], from: d)
        return (weekday, comps.day ?? 0, month, comps.year ?? 0)
    }
}

struct ThingGroup: Identifiable {
    var id: String { date }
    let date: String
    var items: [Thing]
}

func groupByDate(_ things: [Thing]) -> [ThingGroup] {
    var groups: [ThingGroup] = []
    var undated: [Thing] = []
    for t in things {
        guard let date = t.date else { undated.append(t); continue }
        if let idx = groups.firstIndex(where: { $0.date == date }) {
            groups[idx].items.append(t)
        } else {
            groups.append(ThingGroup(date: date, items: [t]))
        }
    }
    groups.sort { $0.date < $1.date }
    if !undated.isEmpty {
        groups.append(ThingGroup(date: "—", items: undated))
    }
    return groups
}

/// Group completed things by completion date, newest first.
func groupByCompletedDate(_ things: [Thing]) -> [ThingGroup] {
    let cal = Calendar.current
    let dated: [(String, Thing)] = things.map { t in
        let key: String
        if let when = t.completedAt {
            key = DateUtil.fmtISO(cal.startOfDay(for: when))
        } else {
            key = "—"
        }
        return (key, t)
    }
    let sorted = dated.sorted { $0.0 > $1.0 }
    var groups: [ThingGroup] = []
    for (date, t) in sorted {
        if let i = groups.firstIndex(where: { $0.date == date }) {
            groups[i].items.append(t)
        } else {
            groups.append(ThingGroup(date: date, items: [t]))
        }
    }
    return groups
}
