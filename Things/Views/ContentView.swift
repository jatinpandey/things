import SwiftUI

enum AppTab: Hashable { case home, add, completed }

@MainActor
final class ThingsStore: ObservableObject {
    @Published var things: [Thing] {
        didSet { Persistence.save(things) }
    }
    @Published var toastMessage: String?

    private var toastTask: Task<Void, Never>?

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

    func showToast(_ message: String, duration: TimeInterval = 1.8) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            toastMessage = message
        }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.toastMessage = nil
            }
        }
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

            // Add tab — selecting it presents a sheet without changing the
            // visible tab. The body is rendered as the current tab's content
            // so SwiftUI never has to morph the selection indicator.
            currentTabContent
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
        .overlay(alignment: .top) {
            if let msg = store.toastMessage {
                ToastView(message: msg)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        // Mirror whatever tab is currently active so the Add "tab" never
        // visually morphs the selection indicator. Selection never actually
        // changes to .add (see `tabBinding`).
        switch selection {
        case .home, .add:
            NavigationStack { HomeView(store: store) }
        case .completed:
            NavigationStack { CompletedView(store: store) }
        }
    }

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .add {
                    // Don't touch `selection` — the visible tab stays put,
                    // and the system tab bar has no source/target morph to
                    // animate. Disable any ambient animation on the sheet
                    // present so it pops cleanly.
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        showingAdd = true
                    }
                } else {
                    selection = newValue
                }
            }
        )
    }
}

struct ToastView: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
            Text(message)
                .font(Fonts.sans(13, weight: .medium))
                .foregroundColor(Theme.text)
                .tracking(-0.1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.5), radius: 14, x: 0, y: 6)
    }
}

#Preview {
    ContentView().preferredColorScheme(.dark)
}
