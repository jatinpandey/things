import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var store: ThingsStore
    var listTitle: String?
    var onBackToLists: (() -> Void)?
    @State private var query: String = ""
    @State private var selectedThingID: Int?
    @State private var movableThingID: Int?
    @State private var activeReorderActivationID: Int?
    @State private var reorderActivationFeedback = UIImpactFeedbackGenerator(style: .heavy)
    @State private var reorderMoveFeedback = UISelectionFeedbackGenerator()

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
    private var rows: [HomeRow] {
        var out: [HomeRow] = []
        for g in groups {
            out.append(.header(date: g.date, count: g.items.count))
            for item in g.items {
                out.append(.item(item))
            }
        }
        return out
    }
    private var todayCount: Int {
        store.active.filter { ($0.date.map(DateUtil.daysFromToday) ?? -999) == 0 }.count
    }
    private var starredCount: Int {
        store.active.filter(\.starred).count
    }
    private var canReorder: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var displayTitle: String {
        listTitle ?? "Things"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let listTitle, let onBackToLists {
                ListContextHeader(title: listTitle, onBack: onBackToLists)
            }

            ZStack {
                Theme.bg.ignoresSafeArea()

                if store.active.isEmpty && query.isEmpty {
                    EmptyHomeState(title: displayTitle)
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .lastTextBaseline) {
                                    Text(displayTitle)
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
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                        }

                        Section {
                            ForEach(rows) { row in
                                switch row {
                                case .header(let date, let count):
                                    DateHeader(iso: date, count: count)
                                        .padding(.horizontal, 18)
                                        .padding(.top, 12)
                                        .padding(.bottom, 2)
                                        .listRowBackground(Theme.bg)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets())
                                        .moveDisabled(true)
                                case .item(let item):
                                    ThingCard(
                                        thing: item,
                                        onTap: { selectedThingID = item.id },
                                        onToggleStar: { store.toggleStar(id: item.id) },
                                        showHandle: canReorder && filtered.count > 1
                                    )
                                    .scaleEffect(movableThingID == item.id ? 1.025 : 1)
                                    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: movableThingID)
                                    .listRowBackground(Theme.bg.opacity(0.01))
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.38)
                                            .onEnded { _ in
                                                guard canReorder, filtered.count > 1 else { return }
                                                signalReorderActivation(for: item.id)
                                            }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        // Done remains the primary (full-swipe)
                                        // action — listed first.
                                        Button {
                                            withAnimation { store.markCompleted(id: item.id) }
                                        } label: {
                                            Label("Done", systemImage: "checkmark")
                                        }
                                        .tint(Theme.accent)

                                        // Delete: secondary, no confirmation here.
                                        // Confirmation only lives in DetailView.
                                        Button(role: .destructive) {
                                            withAnimation { store.delete(id: item.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .onMove { source, destination in
                                guard canReorder else { return }
                                handleCrossGroupMove(source: source, destination: destination)
                                signalReorderMove()
                            }
                        }
                        .textCase(nil)

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

                        // Bottom spacer so the last card scrolls above the
                        // floating bottom bar.
                        Section {
                            Color.clear
                                .frame(height: 110)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .listSectionSpacing(.compact)
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .background(Theme.bg)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationDestination(isPresented: Binding(
            get: { selectedThingID != nil },
            set: { isPresented in
                if !isPresented { selectedThingID = nil }
            }
        )) {
            if let selectedThingID, store.things.contains(where: { $0.id == selectedThingID }) {
                DetailView(store: store, thingID: selectedThingID)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func signalReorderActivation(for id: Int) {
        guard activeReorderActivationID == nil else { return }
        activeReorderActivationID = id
        movableThingID = id
        reorderActivationFeedback.impactOccurred(intensity: 1)
        reorderActivationFeedback.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if movableThingID == id {
                movableThingID = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if activeReorderActivationID == id {
                activeReorderActivationID = nil
            }
        }
    }

    private func signalReorderMove() {
        reorderMoveFeedback.selectionChanged()
        reorderMoveFeedback.prepare()
    }

    private func handleCrossGroupMove(source: IndexSet, destination: Int) {
        var reordered = rows
        reordered.move(fromOffsets: source, toOffset: destination)

        // Walk the new flat order. Each item adopts the date of the most
        // recent header it sits under. If an item lands above the first
        // header (rare; headers are moveDisabled), fall back to the first
        // group's date so the item still belongs to a real group.
        let fallbackDate: String? = groups.first.flatMap { $0.date == "—" ? nil : $0.date }
        var currentDate: String? = fallbackDate
        var ordered: [Thing] = []
        ordered.reserveCapacity(filtered.count)

        for row in reordered {
            switch row {
            case .header(let date, _):
                currentDate = (date == "—") ? nil : date
            case .item(let original):
                var t = original
                t.date = currentDate
                ordered.append(t)
            }
        }

        store.reorderActive(ordered)
    }
}

private enum HomeRow: Identifiable, Equatable {
    case header(date: String, count: Int)
    case item(Thing)

    var id: String {
        switch self {
        case .header(let date, _): return "h:\(date)"
        case .item(let t): return "i:\(t.id)"
        }
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
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
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
