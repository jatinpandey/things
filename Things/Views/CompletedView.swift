import SwiftUI

struct CompletedView: View {
    @ObservedObject var store: ThingsStore

    private var groups: [ThingGroup] { groupByCompletedDate(store.completed) }

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
                        HStack(alignment: .lastTextBaseline) {
                            Text("Completed")
                                .font(Fonts.display(28, weight: .semibold))
                                .foregroundColor(Theme.text)
                                .tracking(-0.8)
                            Spacer()
                            Text("\(store.completed.count) done")
                                .font(Fonts.mono(11))
                                .foregroundColor(Theme.textFaint)
                                .tracking(0.4)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 12, trailing: 18))
                    }

                    ForEach(groups) { g in
                        Section {
                            ForEach(g.items) { item in
                                NavigationLink(value: item.id) {
                                    ThingCard(
                                        thing: item,
                                        onTap: nil,
                                        onToggleStar: { store.toggleStar(id: item.id) }
                                    )
                                    .opacity(0.78)
                                }
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
        .navigationDestination(for: Int.self) { id in
            if store.things.contains(where: { $0.id == id }) {
                DetailView(store: store, thingID: id)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
