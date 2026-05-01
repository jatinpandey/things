import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let thingReorderType = UTType(exportedAs: "com.jatinpandey.things.reorder")

struct HomeView: View {
    @ObservedObject var store: ThingsStore
    @State private var query: String = ""
    @State private var selectedThingID: Int?
    @State private var draggedThingID: Int?
    @State private var reorderFeedback = UISelectionFeedbackGenerator()
    @State private var dragActivationFeedback = UIImpactFeedbackGenerator(style: .light)

    private var filtered: [Thing] {
        let active = store.active
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return active }
        return active.filter { t in
            t.name.lowercased().contains(q)
            || t.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    private var groups: [ThingGroup] { groupByDate(filtered) }
    private var todayCount: Int {
        store.active.filter { ($0.date.map(DateUtil.daysFromToday) ?? -999) == 0 }.count
    }
    private var starredCount: Int {
        store.active.filter(\.starred).count
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if store.active.isEmpty && query.isEmpty {
                EmptyHomeState()
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .lastTextBaseline) {
                                Text("Things")
                                    .font(Fonts.display(28, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                    .tracking(-0.8)
                                Spacer()
                                Text("\(todayCount) today · \(starredCount) starred")
                                    .font(Fonts.mono(11))
                                    .foregroundColor(Theme.textFaint)
                                    .tracking(0.4)
                            }
                            SearchBar(query: $query)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 12, trailing: 18))
                    }

                    ForEach(groups) { g in
                        Section {
                            ForEach(g.items) { item in
                                let canReorder = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && g.items.count > 1
                                ThingCard(
                                    thing: item,
                                    onTap: { selectedThingID = item.id },
                                    onToggleStar: { store.toggleStar(id: item.id) },
                                    onReorderStart: canReorder ? {
                                        beginReorder(for: item.id)
                                        return reorderProvider(for: item.id)
                                    } : nil
                                )
                                .onDrop(
                                    of: [thingReorderType],
                                    delegate: ThingReorderDropDelegate(
                                        target: item,
                                        sectionItems: g.items,
                                        isEnabled: canReorder,
                                        draggedThingID: $draggedThingID,
                                        move: { movingID, targetID in
                                            store.reorderWithinDate(movingID: movingID, over: targetID)
                                        },
                                        onMove: {
                                            reorderFeedback.selectionChanged()
                                            reorderFeedback.prepare()
                                        }
                                    )
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation { store.markCompleted(id: item.id) }
                                    } label: {
                                        Label("Done", systemImage: "checkmark")
                                    }
                                    .tint(Theme.accent)
                                }
                            }
                        } header: {
                            DateHeader(iso: g.date, count: g.items.count)
                                .padding(.horizontal, 18)
                                .padding(.top, 8)
                                .listRowInsets(EdgeInsets())
                                .background(Theme.bg)
                        }
                        .textCase(nil)
                    }

                    if filtered.isEmpty && !query.isEmpty {
                        Section {
                            Text("No things match “\(query)”")
                                .font(Fonts.display(15))
                                .foregroundColor(Theme.textFaint)
                                .tracking(-0.2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }

                    // Bottom spacer above tab bar
                    Section {
                        Color.clear
                            .frame(height: 60)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedThingID != nil },
            set: { isPresented in
                if !isPresented {
                    selectedThingID = nil
                }
            }
        )) {
            if let selectedThingID, store.things.contains(where: { $0.id == selectedThingID }) {
                DetailView(store: store, thingID: selectedThingID)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func beginReorder(for id: Int) {
        draggedThingID = id
        dragActivationFeedback.prepare()
        dragActivationFeedback.impactOccurred(intensity: 0.55)
        reorderFeedback.prepare()
    }

    private func reorderProvider(for id: Int) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: thingReorderType.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(Data("\(id)".utf8), nil)
            return nil
        }
        return provider
    }
}

private struct ThingReorderDropDelegate: DropDelegate {
    let target: Thing
    let sectionItems: [Thing]
    let isEnabled: Bool
    @Binding var draggedThingID: Int?
    let move: (Int, Int) -> Void
    let onMove: () -> Void

    func dropEntered(info: DropInfo) {
        guard isEnabled,
              let movingID = draggedThingID,
              movingID != target.id,
              sectionItems.contains(where: { $0.id == movingID }) else { return }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            move(movingID, target.id)
        }
        onMove()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isEnabled ? DropProposal(operation: .move) : nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard isEnabled else { return false }
        draggedThingID = nil
        return true
    }
}

struct SearchBar: View {
    @Binding var query: String
    var prompt: String = "Search by name or tag"

    var body: some View {
        HStack(spacing: 8) {
            SearchIcon(size: 16, color: Theme.textFaint)
            TextField(
                "",
                text: $query,
                prompt: Text(prompt)
                    .foregroundColor(Theme.textFaint)
            )
            .font(Fonts.sans(14))
            .foregroundColor(Theme.text)
            .textFieldStyle(.plain)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    CloseIcon(size: 16, color: Theme.textFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .hairlineBorder(Theme.hairline, radius: 10)
    }
}

private struct EmptyHomeState: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Things")
                .font(Fonts.display(28, weight: .semibold))
                .foregroundColor(Theme.text)
                .tracking(-0.8)
            Text("Nothing on your mind.")
                .font(Fonts.display(15))
                .foregroundColor(Theme.textFaint)
                .tracking(-0.2)
            Text("Tap + to add your first thing.")
                .font(Fonts.mono(11))
                .foregroundColor(Theme.textFaint)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
