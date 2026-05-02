import SwiftUI

enum AppTab: Hashable { case home, completed }

@MainActor
final class ThingsStore: ObservableObject {
    let listID: UUID
    private let listsStore: ThingListsStore

    var things: [Thing] {
        get { listsStore.list(for: listID)?.things ?? [] }
        set {
            objectWillChange.send()
            listsStore.updateThings(in: listID, things: newValue)
        }
    }
    @Published var toastMessage: String?

    private var toastTask: Task<Void, Never>?

    init(listID: UUID, listsStore: ThingListsStore) {
        self.listID = listID
        self.listsStore = listsStore
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

    /// Top tags across all things, ordered by usage frequency (then
    /// alphabetically), excluding any tag in `excluding`.
    func topTags(limit: Int = 5, excluding: Set<String> = []) -> [String] {
        var counts: [String: Int] = [:]
        for t in things {
            for tag in t.tags { counts[tag, default: 0] += 1 }
        }
        return counts
            .filter { !excluding.contains($0.key) }
            .sorted {
                $0.value != $1.value
                    ? $0.value > $1.value
                    : $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
            }
            .prefix(limit)
            .map(\.key)
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

@MainActor
final class ThingListsStore: ObservableObject {
    @Published var lists: [ThingList] {
        didSet { Persistence.saveLists(lists) }
    }

    init(lists: [ThingList]? = nil) {
        self.lists = lists ?? Persistence.loadLists()
    }

    func list(for id: UUID) -> ThingList? {
        lists.first { $0.id == id }
    }

    @discardableResult
    func addList(named rawName: String) -> UUID {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? nextUntitledName() : trimmed
        let list = ThingList(name: name)
        lists.append(list)
        return list.id
    }

    func updateThings(in listID: UUID, things: [Thing]) {
        guard let i = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[i].things = things
    }

    private func nextUntitledName() -> String {
        let base = "Untitled list"
        guard lists.contains(where: { $0.name == base }) else { return base }

        var n = 2
        while lists.contains(where: { $0.name == "\(base) \(n)" }) {
            n += 1
        }
        return "\(base) \(n)"
    }
}

struct ContentView: View {
    @StateObject private var listsStore = ThingListsStore()
    @State private var selectedListID: UUID?
    @State private var showingNewList = false

    var body: some View {
        Group {
            if let selectedListID, listsStore.list(for: selectedListID) != nil {
                ThingListContentView(
                    listID: selectedListID,
                    listsStore: listsStore,
                    onBack: { self.selectedListID = nil }
                )
                .id(selectedListID)
            } else {
                listsRoot
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingNewList) {
            NewListSheet(store: listsStore)
                .presentationDetents([.height(220)])
                .preferredColorScheme(.dark)
        }
        .onChange(of: listsStore.lists) { _, lists in
            if let selectedListID, !lists.contains(where: { $0.id == selectedListID }) {
                self.selectedListID = nil
            }
        }
    }

    private var listsRoot: some View {
        ListsHomeView(
            store: listsStore,
            onSelect: { selectedListID = $0 },
            onAdd: { showingNewList = true }
        )
    }
}

struct ListsHomeView: View {
    @ObservedObject var store: ThingListsStore
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Things")
                                .font(Fonts.display(32, weight: .semibold))
                                .foregroundColor(Theme.text)
                                .tracking(-0.8)
                            Text("\(store.lists.count) \(store.lists.count == 1 ? "list" : "lists")")
                                .font(Fonts.mono(11))
                                .foregroundColor(Theme.textFaint)
                                .tracking(0.4)
                        }
                        Spacer()
                        Button(action: onAdd) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Theme.bg)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Theme.text))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add list")
                    }
                    .padding(.top, 18)

                    VStack(spacing: 10) {
                        ForEach(store.lists) { list in
                            Button {
                                onSelect(list.id)
                            } label: {
                                ThingListRow(list: list)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ThingListRow: View {
    let list: ThingList

    private var activeCount: Int {
        list.things.filter { !$0.completed }.count
    }

    private var completedCount: Int {
        list.things.filter(\.completed).count
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(list.name)
                    .font(Fonts.display(17, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .tracking(-0.3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(activeCount) active · \(completedCount) done")
                    .font(Fonts.mono(11))
                    .foregroundColor(Theme.textFaint)
                    .tracking(0.4)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .hairlineBorder(Theme.hairline, radius: 8)
    }
}

private struct NewListSheet: View {
    @ObservedObject var store: ThingListsStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(Fonts.sans(14, weight: .medium))
                        .foregroundColor(Theme.textDim)
                        .tracking(-0.1)
                        .buttonStyle(.plain)
                    Spacer()
                    Text("New list")
                        .font(Fonts.display(15, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .tracking(-0.2)
                    Spacer()
                    Button(action: create) {
                        Text("Create")
                            .font(Fonts.sans(13, weight: .semibold))
                            .foregroundColor(canCreate ? Theme.bg : Theme.textFaint)
                            .tracking(-0.1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(canCreate ? Theme.text : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                }

                TextField(
                    "",
                    text: $name,
                    prompt: Text("List name")
                        .foregroundColor(Theme.textFaint)
                )
                .focused($nameFocused)
                .font(Fonts.display(18, weight: .medium))
                .foregroundColor(Theme.text)
                .tracking(-0.4)
                .textFieldStyle(.plain)
                .textContentType(.none)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hairlineBorder(Theme.hairline, radius: 8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFocused = true
            }
        }
    }

    private func create() {
        guard canCreate else { return }
        store.addList(named: name)
        dismiss()
    }
}

private struct MissingListView: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            Text("List not found")
                .font(Fonts.display(15))
                .foregroundColor(Theme.textFaint)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ThingListContentView: View {
    @ObservedObject var listsStore: ThingListsStore
    @StateObject private var store: ThingsStore
    let onBack: () -> Void
    @State private var selection: AppTab = .home
    @State private var showingAdd = false

    init(listID: UUID, listsStore: ThingListsStore, onBack: @escaping () -> Void) {
        self._listsStore = ObservedObject(wrappedValue: listsStore)
        self._store = StateObject(wrappedValue: ThingsStore(listID: listID, listsStore: listsStore))
        self.onBack = onBack
    }

    private var listName: String {
        listsStore.list(for: store.listID)?.name ?? "List"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .home:
                    NavigationStack {
                        HomeView(store: store, listTitle: listName, onBackToLists: onBack)
                    }
                case .completed:
                    NavigationStack {
                        CompletedView(store: store, listTitle: listName, onBackToLists: onBack)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgDeep.ignoresSafeArea())

            BottomBar(
                selection: $selection,
                onAdd: { showingAdd = true }
            )
        }
        .background(Theme.bg.ignoresSafeArea())
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
}

struct ListContextHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 2) {
                    BackIcon(size: 20, color: Theme.textDim)
                    Text("Things")
                        .font(Fonts.sans(14))
                        .foregroundColor(Theme.textDim)
                        .tracking(-0.1)
                }
                .padding(.leading, 4)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairlineSoft).frame(height: 0.5)
        }
    }
}

struct BottomBar: View {
    @Binding var selection: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            BarButton(
                icon: "list.bullet",
                label: "List",
                active: selection == .home
            ) { selection = .home }

            // The Add button intentionally has no `active` state and no
            // selection-tied animation — tapping it only opens the sheet.
            BarButton(
                icon: "plus",
                label: "Add",
                active: false
            ) { onAdd() }

            BarButton(
                icon: "checkmark.circle",
                label: "Completed",
                active: selection == .completed
            ) { selection = .completed }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairlineSoft).frame(height: 0.5)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct BarButton: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(active ? Theme.text : Theme.textDim)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(BarButtonStyle())
        .accessibilityLabel(label)
    }
}

/// Tap feedback only — no opacity/scale press animation, no morph.
private struct BarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
