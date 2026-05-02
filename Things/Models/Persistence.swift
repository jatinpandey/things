import Foundation

enum Persistence {
    private static let legacyThingsKey = "things.v1"
    private static let listsKey = "thingLists.v1"
    private static let defaults = UserDefaults.standard

    static func loadLists() -> [ThingList] {
        if let data = defaults.data(forKey: listsKey),
           let lists = try? JSONDecoder().decode([ThingList].self, from: data),
           !lists.isEmpty {
            return lists
        }

        return [ThingList(name: "things to do", things: loadLegacyThings())]
    }

    static func saveLists(_ lists: [ThingList]) {
        do {
            let data = try JSONEncoder().encode(lists)
            defaults.set(data, forKey: listsKey)
        } catch {
            // best effort
        }
    }

    private static func loadLegacyThings() -> [Thing] {
        guard let data = defaults.data(forKey: legacyThingsKey) else { return [] }
        do {
            return try JSONDecoder().decode([Thing].self, from: data)
        } catch {
            return []
        }
    }
}
