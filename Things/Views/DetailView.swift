import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ThingsStore
    let thingID: Int
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete = false
    @State private var goingToEdit = false

    private var thing: Thing? { store.things.first(where: { $0.id == thingID }) }

    private var dateInfo: (label: String, relative: String, isToday: Bool)? {
        guard let iso = thing?.date else { return nil }
        let diff = DateUtil.daysFromToday(iso)
        let rel: String
        switch diff {
        case 0:  rel = "today"
        case 1:  rel = "tomorrow"
        case -1: rel = "yesterday"
        default: rel = diff > 0 ? "in \(diff) days" : "\(-diff) days ago"
        }
        return (DateUtil.dayLabel(iso), rel, diff == 0)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let thing {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 2) {
                                BackIcon(size: 20, color: Theme.textDim)
                                Text("Back")
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

                        if !thing.completed {
                            NavigationLink(value: EditRoute(id: thing.id)) {
                                Text("Edit")
                                    .font(Fonts.sans(13, weight: .medium))
                                    .foregroundColor(Theme.text)
                                    .tracking(-0.1)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.surface))
                                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .topTrailing) {
                                VStack(alignment: .leading, spacing: 0) {
                                    if let info = dateInfo {
                                        HStack(spacing: 6) {
                                            CalIcon(size: 12, color: info.isToday ? Theme.accent : Theme.textDim)
                                            Text("\(info.label) · \(info.relative)")
                                                .font(Fonts.mono(11, weight: .medium))
                                                .foregroundColor(info.isToday ? Theme.accent : Theme.textDim)
                                                .tracking(0.3)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(info.isToday ? Theme.accentDim : Theme.surface2))
                                        .overlay(Capsule().strokeBorder(info.isToday ? Theme.accentBorder : Theme.hairline, lineWidth: 0.5))
                                        .padding(.trailing, 32)
                                    }

                                    Text(thing.name)
                                        .font(Fonts.display(26, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                        .tracking(-0.6)
                                        .lineSpacing(1.2 * 26 - 26)
                                        .padding(.top, 14)
                                        .padding(.trailing, 8)
                                        .padding(.bottom, 18)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .strikethrough(thing.completed, color: Theme.textFaint)

                                    if !thing.tags.isEmpty {
                                        Rectangle()
                                            .fill(Theme.hairline)
                                            .frame(height: 0.5)
                                            .padding(.horizontal, -22)
                                            .padding(.bottom, 16)

                                        Text("TAGS")
                                            .font(Fonts.mono(10, weight: .medium))
                                            .foregroundColor(Theme.textFaint)
                                            .tracking(1)
                                            .padding(.bottom, 8)

                                        FlowLayout(spacing: 5, runSpacing: 5) {
                                            ForEach(Array(thing.tags.enumerated()), id: \.offset) { _, tag in
                                                TagChip(label: tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 22)

                                Button(action: { store.toggleStar(id: thing.id) }) {
                                    StarIcon(
                                        filled: thing.starred,
                                        size: 22,
                                        color: thing.starred ? Theme.accent : Theme.textFaint
                                    )
                                    .padding(6)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 14)
                                .padding(.trailing, 14)
                            }
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .hairlineBorder(thing.starred ? Theme.accentBorderStrong : Theme.hairline, radius: 14)
                            .opacity(thing.completed ? 0.78 : 1)

                            HStack(spacing: 8) {
                                Button {
                                    if thing.completed {
                                        store.markActive(id: thing.id)
                                    } else {
                                        store.markCompleted(id: thing.id)
                                    }
                                    dismiss()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: thing.completed ? "arrow.uturn.backward" : "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(thing.completed ? "MARK ACTIVE" : "MARK DONE")
                                            .font(Fonts.mono(11, weight: .medium))
                                            .tracking(0.6)
                                    }
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Theme.accentDim)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Theme.accentBorder, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)

                                Button(action: { pendingDelete = true }) {
                                    HStack(spacing: 6) {
                                        TrashIcon(size: 13, color: Theme.danger)
                                        Text("DELETE")
                                            .font(Fonts.mono(11, weight: .medium))
                                            .foregroundColor(Theme.danger)
                                            .tracking(0.6)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 22)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
            } else {
                Color.clear.onAppear { dismiss() }
            }

            if pendingDelete, let thing {
                ConfirmDialog(
                    title: "Delete this thing?",
                    message: "“\(thing.name)” will be removed. This can't be undone.",
                    confirmLabel: "Delete",
                    onConfirm: {
                        pendingDelete = false
                        store.delete(id: thing.id)
                        dismiss()
                    },
                    onCancel: { pendingDelete = false }
                )
            }
        }
        .navigationDestination(for: EditRoute.self) { route in
            if let t = store.things.first(where: { $0.id == route.id }) {
                EditorView(
                    store: store,
                    initial: t,
                    isNew: false,
                    onClose: nil
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct EditRoute: Hashable { let id: Int }
