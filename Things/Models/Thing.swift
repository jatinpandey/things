import Foundation

struct Thing: Identifiable, Equatable, Codable {
    var id: Int
    var name: String
    var date: String?     // ISO yyyy-MM-dd, optional
    var tags: [String]
    var starred: Bool
    var completed: Bool = false
    var completedAt: Date? = nil
    var repeatRule: RepeatRule? = nil
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly

    var id: Self { self }

    var label: String {
        switch self {
        case .daily:   "Daily"
        case .weekly:  "Weekly"
        case .monthly: "Monthly"
        }
    }

    /// Next occurrence strictly after `iso`, advanced until it's not in the
    /// past (so completing a long-overdue repeating thing lands on the next
    /// upcoming slot, not a stack of missed ones).
    func nextISO(after iso: String) -> String? {
        guard var d = DateUtil.parseISO(iso) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let (component, amount): (Calendar.Component, Int) = switch self {
        case .daily:   (.day, 1)
        case .weekly:  (.day, 7)
        case .monthly: (.month, 1)
        }
        repeat {
            guard let n = cal.date(byAdding: component, value: amount, to: d) else { return nil }
            d = n
        } while d < today
        return DateUtil.fmtISO(d)
    }
}

/// Detects a natural-language date inside free text ("call mom tomorrow",
/// "dentist on friday", "renew passport may 12").
enum DateSuggestion {
    static func detect(in text: String) -> (iso: String, matched: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        for m in detector.matches(in: text, options: [], range: range) {
            guard let date = m.date, let r = Range(m.range, in: text) else { continue }
            let matched = String(text[r])
            // Skip time-only matches like "4:15" or "10 pm" — we only care
            // about calendar days.
            if matched.range(
                of: #"^[\d:.\s]+(am|pm)?$"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil { continue }
            let iso = DateUtil.fmtISO(date)
            guard DateUtil.daysFromToday(iso) >= 0 else { continue }
            return (iso, matched)
        }
        return nil
    }

    /// Remove the matched phrase (and a dangling connector word) from the title.
    static func strip(_ matched: String, from text: String) -> String {
        var out = text.replacingOccurrences(of: matched, with: "")
        out = out.replacingOccurrences(
            of: #"\s{2,}"#, with: " ", options: .regularExpression
        )
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        for connector in ["on", "at", "by", "due", "for", "-", "–", "—"] {
            if out.lowercased().hasSuffix(" " + connector) {
                out = String(out.dropLast(connector.count + 1))
            } else if out.lowercased() == connector {
                out = ""
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ThingList: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var things: [Thing]

    init(id: UUID = UUID(), name: String, things: [Thing] = []) {
        self.id = id
        self.name = name
        self.things = things
    }
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
    let dates = Set(things.compactMap(\.date)).sorted()
    var groups = dates.map { date in
        ThingGroup(date: date, items: things.filter { $0.date == date })
    }

    let undated = things.filter { $0.date == nil }
    if !undated.isEmpty {
        groups.append(ThingGroup(date: "—", items: undated))
    }

    return groups
}

/// Group completed things by their own event date, newest first.
func groupByCompletedDate(_ things: [Thing]) -> [ThingGroup] {
    let dated: [(String, Thing)] = things.map { ($0.date ?? "—", $0) }
    let sorted = dated.sorted {
        switch ($0.0, $1.0) {
        case ("—", "—"):
            return $0.1.name < $1.1.name
        case ("—", _):
            return false
        case (_, "—"):
            return true
        default:
            return $0.0 > $1.0
        }
    }
    var groups: [ThingGroup] = []
    for (date, t) in sorted {
        if let i = groups.firstIndex(where: { $0.date == date }) {
            groups[i].items.append(t)
        } else {
            groups.append(ThingGroup(date: date, items: [t]))
        }
    }
    for i in groups.indices {
        groups[i].items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    return groups
}
