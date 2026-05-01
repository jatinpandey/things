import SwiftUI

enum AppTab: Hashable { case home, add, completed }

@MainActor
final class ThingsStore: ObservableObject {
    @Published var things: [Thing] {
        didSet { Persistence.save(things) }
    }

    init(things: [Thing]? = nil) {
        self.things = things ?? Persistence.load()
    }

    var active:    [Thing] { things.filter { !$0.completed } }
    var completed: [Thing] { things.filter {  $0.completed } }

    func toggleStar(id: Int) {
        guard let i = things.firstIndex(where: { $0.id == id }) else { return }
        things[i].starred.toggle()
    }

    /// Reorder within a single date group.
    /// `sectionItems` is the group's current order; `source`/`destination` are
    /// indices into that section (as `.onMove` provides them).
    func move(within sectionItems: [Thing], from source: IndexSet, to destination: Int) {
        var newSection = sectionItems
        newSection.move(fromOffsets: source, toOffset: destination)

        let sectionIDs = Set(sectionItems.map(\.id))
        let slots = things.indices.filter { sectionIDs.contains(things[$0].id) }
        let lookup: [Int: Thing] = Dictionary(uniqueKeysWithValues:
            things.filter { sectionIDs.contains($0.id) }.map { ($0.id, $0) }
        )

        var next = things
        for (slot, item) in zip(slots, newSection) {
            if let t = lookup[item.id] { next[slot] = t }
        }
        things = next
    }

    func save(_ next: Thing) {
        if let i = things.firstIndex(where: { $0.id == next.id }) {
            things[i] = next
        } else {
            things.append(next)
        }
    }

    func nextID() -> Int { (things.map(\.id).max() ?? 0) + 1 }

    func delete(id: Int) {
        things.removeAll { $0.id == id }
    }

    func markCompleted(id: Int) {
        guard let i = things.firstIndex(where: { $0.id == id }) else { return }
        things[i].completed = true
        things[i].completedAt = Date()
    }

    func markActive(id: Int) {
        guard let i = things.firstIndex(where: { $0.id == id }) else { return }
        things[i].completed = false
        things[i].completedAt = nil
    }
}

struct ContentView: View {
    @StateObject private var store = ThingsStore()
    @State private var selection: AppTab = .home
    @State private var showingAdd = false

    var body: some View {
        TabView(selection: tabBinding) {
            NavigationStack {
                HomeView(store: store)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            // The Add tab never actually shows — selecting it presents a sheet.
            Color.clear
                .tabItem { Label("Add", systemImage: "plus") }
                .tag(AppTab.add)

            NavigationStack {
                CompletedView(store: store)
            }
            .tabItem { Label("Completed", systemImage: "checkmark") }
            .tag(AppTab.completed)
        }
        .tint(Theme.accent)
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                EditorView(
                    store: store,
                    initial: Thing(
                        id: store.nextID(),
                        name: "",
                        date: DateUtil.fmtISO(Date()),
                        tags: [],
                        starred: false
                    ),
                    isNew: true,
                    onClose: { showingAdd = false }
                )
            }
            .preferredColorScheme(.dark)
        }
    }

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .add {
                    showingAdd = true
                } else {
                    selection = newValue
                }
            }
        )
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
