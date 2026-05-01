import Foundation

enum Persistence {
    private static let key = "things.v1"
    private static let defaults = UserDefaults.standard

    static func load() -> [Thing] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([Thing].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ things: [Thing]) {
        do {
            let data = try JSONEncoder().encode(things)
            defaults.set(data, forKey: key)
        } catch {
            // best effort
        }
    }
}
