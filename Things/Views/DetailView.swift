import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ThingsStore
    let thingID: Int
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete = false
    @FocusState private var nameFocused: Bool

    private var thing: Thing? { store.things.first(where: { $0.id == thingID }) }

    private var thingBinding: Binding<Thing> {
        Binding(
            get: {
                store.things.first(where: { $0.id == thingID })
                    ?? Thing(id: thingID, name: "", date: nil, tags: [], starred: false)
            },
            set: { new in
                if let i = store.things.firstIndex(where: { $0.id == thingID }) {
                    store.things[i] = new
                }
            }
        )
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
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    ScrollView {
                        editorBody(thing: thing)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                    }
                    .scrollDismissesKeyboard(.interactively)
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
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func editorBody(thing: Thing) -> some View {
        let b = thingBinding

        VStack(spacing: 0) {
            FieldRow(label: "Title") {
                HStack(alignment: .top, spacing: 10) {
                    TextField(
                        "",
                        text: b.name,
                        prompt: Text("Add a new Thing")
                            .foregroundColor(Theme.textFaint),
                        axis: .vertical
                    )
                    .focused($nameFocused)
                    .font(Fonts.display(16, weight: .medium))
                    .foregroundColor(Theme.text)
                    .tracking(-0.4)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .strikethrough(thing.completed, color: Theme.textFaint)
                    
                    Button(action: { store.toggleStar(id: thing.id) }) {
                        StarIcon(
                            filled: thing.starred,
                            size: 22,
                            color: thing.starred ? Theme.accent : Theme.textFaint
                        )
                        .padding(4)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, -4)
                    .padding(.top, 2)
                }
            }

            FieldRow(
                label: "When",
                optional: thing.date != nil,
                onClear: { b.wrappedValue.date = nil }
            ) {
                if thing.date != nil {
                    DatePickerRow(value: Binding(
                        get: { b.wrappedValue.date ?? DateUtil.fmtISO(Date()) },
                        set: { b.wrappedValue.date = $0 }
                    ))
                } else {
                    Button(action: { b.wrappedValue.date = DateUtil.fmtISO(Date()) }) {
                        HStack(spacing: 6) {
                            CalIcon(size: 14, color: Theme.textDim)
                            Text("add a date")
                                .font(Fonts.sans(13))
                                .foregroundColor(Theme.textDim)
                                .tracking(-0.1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule().strokeBorder(
                                Theme.hairline,
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            FieldRow(
                label: "Tags",
                optional: false,
                onClear: { b.wrappedValue.tags = [] }
            ) {
                TagEditor(tags: b.tags)
            }

            VStack(spacing: 10) {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 28)
        }
    }
}
