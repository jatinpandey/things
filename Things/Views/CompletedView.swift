import SwiftUI

struct CompletedView: View {
    @ObservedObject var store: ThingsStore
    @State private var query: String = ""
    @State private var selectedThingID: Int?

    private var filtered: [Thing] {
        let completed = store.completed
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return completed }
        return completed.filter { searchableText(for: $0).lowercased().contains(q) }
    }

    private var groups: [ThingGroup] { groupByCompletedDate(filtered) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if store.completed.isEmpty {
                VStack(spacing: 12) {
                    Text("Completed")
                        .font(Fonts.display(28, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .tracking(-0.8)
                    Text("Nothing finished yet.")
                        .font(Fonts.display(15))
                        .foregroundColor(Theme.textFaint)
                        .tracking(-0.2)
                    Text("Swipe a thing left on Home to mark it done.")
                        .font(Fonts.mono(11))
                        .foregroundColor(Theme.textFaint)
                        .tracking(0.4)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .lastTextBaseline) {
                                Text("Completed")
                                    .font(Fonts.display(28, weight: .semibold))
                                    .foregroundColor(Theme.text)
                                    .tracking(-0.8)
                                Spacer()
                                Text(completedCountText)
                                    .font(Fonts.mono(11))
                                    .foregroundColor(Theme.textFaint)
                                    .tracking(0.4)
                            }
                            SearchBar(query: $query, prompt: "Search title, tag, date, month")
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 12, trailing: 18))
                    }

                    ForEach(groups) { g in
                        Section {
                            ForEach(g.items) { item in
                                ThingCard(
                                    thing: item,
                                    onTap: { selectedThingID = item.id },
                                    onToggleStar: { store.toggleStar(id: item.id) }
                                )
                                .opacity(0.78)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 4, trailing: 18))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation { store.markActive(id: item.id) }
                                    } label: {
                                        Label("Undo", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(Theme.textDim)

                                    Button(role: .destructive) {
                                        withAnimation { store.delete(id: item.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            CompletedDateHeader(iso: g.date, count: g.items.count)
                                .padding(.horizontal, 18)
                                .padding(.top, 8)
                                .listRowInsets(EdgeInsets())
                                .background(Theme.bg)
                        }
                        .textCase(nil)
                    }

                    if filtered.isEmpty && !query.isEmpty {
                        Section {
                            Text("No completed things match “\(query)”")
                                .font(Fonts.display(15))
                                .foregroundColor(Theme.textFaint)
                                .tracking(-0.2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }

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

    private var completedCountText: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(store.completed.count) done"
        }

        return "\(filtered.count) of \(store.completed.count)"
    }

    private func searchableText(for thing: Thing) -> String {
        var parts = [thing.name]
        parts.append(contentsOf: thing.tags)

        if let date = thing.date {
            parts.append(date)
            parts.append(DateUtil.dayLabel(date))

            let meta = DateUtil.dayMeta(date)
            parts.append(meta.weekday)
            parts.append(meta.month)
            parts.append(String(meta.day))
            parts.append(String(meta.year))

            if let parsedDate = DateUtil.parseISO(date) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day, .month, .year], from: parsedDate)
                let day = components.day ?? meta.day
                let month = components.month ?? 0
                let year = components.year ?? meta.year

                parts.append("\(day)/\(month)")
                parts.append("\(month)/\(day)")
                parts.append("\(day)-\(month)")
                parts.append("\(month)-\(day)")
                parts.append("\(day)/\(month)/\(year)")

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "MMMM"
                parts.append(formatter.string(from: parsedDate))
            }
        } else {
            parts.append("untimed")
        }

        return parts.joined(separator: " ")
    }
}

private struct CompletedDateHeader: View {
    let iso: String
    let count: Int

    private var label: String {
        iso == "—" ? "Earlier" : DateUtil.dayLabel(iso)
    }
    private var meta: (weekday: String, day: Int, month: String, year: Int)? {
        iso == "—" ? nil : DateUtil.dayMeta(iso)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(Fonts.display(15, weight: .semibold))
                .foregroundColor(Theme.textDim)
                .tracking(-0.2)
            if let meta {
                Text("\(meta.month) \(meta.day) · \(count) done")
                    .font(Fonts.mono(10))
                    .foregroundColor(Theme.textFaint)
                    .tracking(0.4)
            } else {
                Text("\(count) done")
                    .font(Fonts.mono(10))
                    .foregroundColor(Theme.textFaint)
                    .tracking(0.4)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.bottom, 6)
    }
}
