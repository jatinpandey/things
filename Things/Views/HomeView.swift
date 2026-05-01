import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var store: ThingsStore
    @State private var query: String = ""
    @State private var selectedThingID: Int?

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
    private var canReorder: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                    }

                    ForEach(groups) { g in
                        Section {
                            ForEach(g.items) { item in
                                ThingCard(
                                    thing: item,
                                    onTap: { selectedThingID = item.id },
                                    onToggleStar: { store.toggleStar(id: item.id) },
                                    showHandle: canReorder && g.items.count > 1
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.45)
                                        .onEnded { _ in
                                            guard canReorder, g.items.count > 1 else { return }
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation { store.markCompleted(id: item.id) }
                                    } label: {
                                        Label("Done", systemImage: "checkmark")
                                    }
                                    .tint(Theme.accent)
                                }
                            }
                            .onMove { source, destination in
                                guard canReorder else { return }
                                store.move(within: g.items, from: source, to: destination)
                            }
                        } header: {
                            DateHeader(iso: g.date, count: g.items.count)
                                .padding(.horizontal, 18)
                                .padding(.top, 4)
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
                .listSectionSpacing(.compact)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .background(Theme.bg)
                .scrollDismissesKeyboard(.interactively)
            }
        }
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
