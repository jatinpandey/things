import SwiftUI

enum AppTab: Hashable { case home, completed }

enum AppAppearance: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: Self { self }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var icon: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

struct ToastData {
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
}

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
    @Published var toast: ToastData?

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

    /// Replace the active sub-sequence of `things` with `ordered`, preserving
    /// completed items in their existing absolute positions. Each `Thing` in
    /// `ordered` may carry an updated `date` to reflect cross-group moves.
    func reorderActive(_ ordered: [Thing]) {
        let activeIDs = Set(ordered.map(\.id))
        let slots = things.indices.filter { activeIDs.contains(things[$0].id) }
        guard slots.count == ordered.count else { return }

        var next = things
        for (slot, item) in zip(slots, ordered) {
            next[slot] = item
        }
        things = next
    }

    func save(_ next: Thing) {
        if let i = things.firstIndex(where: { $0.id == next.id }) {
            let was = things[i]
            things[i] = next
            // Completing via the editor spawns the next repeat occurrence,
            // same as the swipe path.
            if !was.completed && next.completed {
                spawnRepeatIfNeeded(for: next)
            }
        } else {
            things.append(next)
        }
    }

    func nextID() -> Int { (things.map(\.id).max() ?? 0) + 1 }

    func delete(id: Int) {
        things.removeAll { $0.id == id }
    }

    /// Re-insert a previously deleted thing at (close to) its old position.
    func restore(_ thing: Thing, at index: Int?) {
        guard !things.contains(where: { $0.id == thing.id }) else { return }
        var next = things
        next.insert(thing, at: min(index ?? next.endIndex, next.endIndex))
        things = next
    }

    /// Marks the thing completed. If it repeats, spawns the next occurrence
    /// and returns the spawned thing's id (so an Undo can remove it again).
    @discardableResult
    func markCompleted(id: Int) -> Int? {
        guard let i = things.firstIndex(where: { $0.id == id }) else { return nil }
        things[i].completed = true
        things[i].completedAt = Date()
        return spawnRepeatIfNeeded(for: things[i])
    }

    func markActive(id: Int) {
        guard let i = things.firstIndex(where: { $0.id == id }) else { return }
        things[i].completed = false
        things[i].completedAt = nil
    }

    func undoComplete(id: Int, spawnedID: Int?) {
        if let spawnedID {
            things.removeAll { $0.id == spawnedID }
        }
        markActive(id: id)
    }

    func moveToToday(id: Int) {
        guard let i = things.firstIndex(where: { $0.id == id }) else { return }
        things[i].date = DateUtil.fmtISO(Date())
    }

    @discardableResult
    private func spawnRepeatIfNeeded(for thing: Thing) -> Int? {
        guard let rule = thing.repeatRule,
              let date = thing.date,
              let next = rule.nextISO(after: date) else { return nil }
        var clone = thing
        clone.id = nextID()
        clone.date = next
        clone.completed = false
        clone.completedAt = nil
        things.append(clone)
        return clone.id
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

    func showToast(
        _ message: String,
        actionLabel: String? = nil,
        duration: TimeInterval? = nil,
        action: (() -> Void)? = nil
    ) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            toast = ToastData(message: message, actionLabel: actionLabel, action: action)
        }
        // Toasts with an Undo action linger longer.
        let lifetime = duration ?? (action == nil ? 1.8 : 4.0)
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.toast = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toast = nil
        }
    }
}

@MainActor
final class ThingListsStore: ObservableObject {
    @Published var lists: [ThingList] {
        didSet {
            Persistence.saveLists(lists)
            NotificationManager.sync(lists: lists)
        }
    }

    init(lists: [ThingList]? = nil) {
        self.lists = lists ?? Persistence.loadLists()
    }

    func list(for id: UUID) -> ThingList? {
        lists.first { $0.id == id }
    }

    func renameList(id: UUID, to rawName: String) {
        let name = normalizedName(rawName)
        guard let i = lists.firstIndex(where: { $0.id == id }) else { return }
        lists[i].name = name
    }

    @discardableResult
    func addList(named rawName: String) -> UUID {
        let list = ThingList(name: normalizedName(rawName))
        lists.append(list)
        return list.id
    }

    func deleteLists(at offsets: IndexSet) {
        lists.remove(atOffsets: offsets)
    }

    func deleteList(id: UUID) {
        lists.removeAll { $0.id == id }
    }

    func moveLists(from source: IndexSet, to destination: Int) {
        lists.move(fromOffsets: source, toOffset: destination)
    }

    func updateThings(in listID: UUID, things: [Thing]) {
        guard let i = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[i].things = things
    }

    private func normalizedName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nextUntitledName() : trimmed
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
    @State private var appearance: AppAppearance = .dark

    var body: some View {
        ZStack {
            if let selectedListID, listsStore.list(for: selectedListID) != nil {
                ThingListContentView(
                    listID: selectedListID,
                    listsStore: listsStore,
                    onBack: { self.selectedListID = nil }
                )
                .id(selectedListID)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                listsRoot
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: selectedListID)
        .preferredColorScheme(appearance.colorScheme)
        .sheet(isPresented: $showingNewList) {
            NewListSheet(store: listsStore)
                .presentationDetents([.height(220)])
                .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: listsStore.lists) { _, lists in
            if let selectedListID, !lists.contains(where: { $0.id == selectedListID }) {
                self.selectedListID = nil
            }
        }
        .task {
            NotificationManager.requestAuthorizationIfNeeded()
            NotificationManager.sync(lists: listsStore.lists)
        }
    }

    private var listsRoot: some View {
        ListsHomeView(
            store: listsStore,
            appearance: $appearance,
            onSelect: { selectedListID = $0 },
            onAdd: { showingNewList = true }
        )
    }
}

struct ListsHomeView: View {
    @ObservedObject var store: ThingListsStore
    @Binding var appearance: AppAppearance
    let onSelect: (UUID) -> Void
    let onAdd: () -> Void
    @State private var editMode: EditMode = .inactive
    @State private var listBeingRenamed: ThingList?

    private var isEditing: Bool {
        editMode.isEditing
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            List {
                Section {
                    HStack(alignment: .top) {
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
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                editMode = isEditing ? .inactive : .active
                            }
                        } label: {
                            Text(isEditing ? "Done" : "Edit")
                                .font(Fonts.sans(13, weight: .semibold))
                                .foregroundColor(Theme.text)
                                .tracking(-0.1)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(Theme.surface)
                                .clipShape(Capsule())
                                .hairlineBorder(Theme.hairline, radius: 999)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isEditing ? "Finish editing lists" : "Edit lists")

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
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 8, trailing: 18))
                }

                Section {
                    ForEach(store.lists) { list in
                        Button {
                            if isEditing {
                                listBeingRenamed = list
                            } else {
                                onSelect(list.id)
                            }
                        } label: {
                            ThingListRow(list: list, isEditing: isEditing)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                listBeingRenamed = list
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                withAnimation { store.deleteList(id: list.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                listBeingRenamed = list
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(Theme.accent)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { store.deleteList(id: list.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Theme.bg.opacity(0.01))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                    }
                    .onMove(perform: store.moveLists)
                    .onDelete(perform: store.deleteLists)
                }
                .textCase(nil)

                if store.lists.isEmpty {
                    Section {
                        Text("No lists yet")
                            .font(Fonts.display(15))
                            .foregroundColor(Theme.textFaint)
                            .tracking(-0.2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 54)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    Color.clear
                        .frame(height: 104)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .environment(\.editMode, $editMode)

            AppearancePicker(selection: $appearance)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $listBeingRenamed) { list in
            ListNameSheet(
                title: "Rename list",
                actionTitle: "Save",
                initialName: list.name
            ) { name in
                store.renameList(id: list.id, to: name)
            }
            .presentationDetents([.height(220)])
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}

private struct AppearancePicker: View {
    @Binding var selection: AppAppearance

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppAppearance.allCases) { appearance in
                Button {
                    selection = appearance
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: appearance.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(appearance.rawValue)
                            .font(Fonts.sans(13, weight: .semibold))
                            .tracking(-0.1)
                    }
                    .foregroundColor(selection == appearance ? Theme.bg : Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(selection == appearance ? Theme.text : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.surface)
        .clipShape(Capsule())
        .hairlineBorder(Theme.hairline, radius: 999)
    }
}

private struct ThingListRow: View {
    let list: ThingList
    let isEditing: Bool

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
            Image(systemName: isEditing ? "pencil" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textFaint)
                .frame(width: 18)
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

private struct ListNameSheet: View {
    let title: String
    let actionTitle: String
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(
        title: String,
        actionTitle: String,
        initialName: String,
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSubmit = onSubmit
        self._name = State(initialValue: initialName)
    }

    private var canSubmit: Bool {
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
                    Text(title)
                        .font(Fonts.display(15, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .tracking(-0.2)
                    Spacer()
                    Button(action: submit) {
                        Text(actionTitle)
                            .font(Fonts.sans(13, weight: .semibold))
                            .foregroundColor(canSubmit ? Theme.bg : Theme.textFaint)
                            .tracking(-0.1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(canSubmit ? Theme.text : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
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
                .onSubmit(submit)
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

    private func submit() {
        guard canSubmit else { return }
        onSubmit(name)
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
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(toast: toast, onAction: { store.dismissToast() })
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    // Only intercept touches when there's an action to tap.
                    .allowsHitTesting(toast.action != nil)
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
        .padding(.top, 6)
        .padding(.bottom, 10)
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(active ? Theme.text : Theme.textDim)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
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
    let toast: ToastData
    /// Called after the action runs, so the host can dismiss the toast.
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
            Text(toast.message)
                .font(Fonts.sans(13, weight: .medium))
                .foregroundColor(Theme.text)
                .tracking(-0.1)

            if let label = toast.actionLabel, let action = toast.action {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 0.5, height: 16)
                    .padding(.horizontal, 2)
                Button {
                    action()
                    onAction?()
                } label: {
                    Text(label)
                        .font(Fonts.sans(13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .tracking(-0.1)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
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
