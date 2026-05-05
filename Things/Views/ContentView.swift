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

    /// Move `draggedID` to the slot currently held by `targetID`, adopting
    /// the target's date. If `targetID` is nil, the item moves to the queue
    /// (date = nil) at the end of the list.
    func reorder(draggedID: Int, targetID: Int?) {
        guard let from = things.firstIndex(where: { $0.id == draggedID }) else { return }
        var item = things.remove(at: from)
        if let targetID, let to = things.firstIndex(where: { $0.id == targetID }) {
            item.date = things[to].date
            things.insert(item, at: to)
        } else {
            item.date = nil
            things.append(item)
        }
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
