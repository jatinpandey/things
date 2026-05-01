import SwiftUI

struct ConfirmDialog: View {
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onCancel() }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Fonts.display(17, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .tracking(-0.3)
                    .padding(.bottom, 6)
                Text(message)
                    .font(Fonts.sans(13))
                    .foregroundColor(Theme.textDim)
                    .tracking(-0.1)
                    .lineSpacing(13 * 1.45 - 13)
                    .padding(.bottom, 18)
                HStack(spacing: 8) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(Fonts.sans(13, weight: .medium))
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .hairlineBorder(Theme.hairline, radius: 10)
                    }
                    .buttonStyle(.plain)
                    Button(action: onConfirm) {
                        Text(confirmLabel)
                            .font(Fonts.sans(13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.danger)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .hairlineBorder(Theme.hairline, radius: 16)
            .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 20)
            .padding(24)
        }
    }
}

struct FieldRow<Content: View>: View {
    let label: String
    var optional: Bool = false
    var onClear: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label.uppercased())
                    .font(Fonts.mono(10, weight: .medium))
                    .foregroundColor(Theme.textFaint)
                    .tracking(1.2)
                Spacer()
                if optional, let onClear {
                    Button(action: onClear) {
                        Text("REMOVE")
                            .font(Fonts.mono(10, weight: .medium))
                            .foregroundColor(Theme.danger)
                            .tracking(0.6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
            content
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairlineSoft).frame(height: 0.5)
        }
    }
}

struct DatePickerRow: View {
    @Binding var value: String
    var quickChoices: Bool = true
    @State private var openPick = false

    private var todayISO: String { DateUtil.fmtISO(Date()) }
    private var tomorrowISO: String {
        let d = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return DateUtil.fmtISO(d)
    }

    private var isPick: Bool { value != todayISO && value != tomorrowISO }

    var body: some View {
        if quickChoices {
            quickChoicePicker
        } else {
            dateTilePicker
        }
    }

    private var quickChoicePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                pill(active: value == todayISO, label: "Today") {
                    value = todayISO; openPick = false
                }
                pill(active: value == tomorrowISO, label: "Tomorrow") {
                    value = tomorrowISO; openPick = false
                }
                pill(active: isPick || openPick, label: "Custom") {
                    openPick.toggle()
                }
                Spacer(minLength: 0)
            }
            if openPick {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { DateUtil.parseISO(value) ?? Date() },
                        set: { value = DateUtil.fmtISO($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(Theme.accent)
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .hairlineBorder(Theme.hairline, radius: 12)
            }
        }
    }

    private var dateTilePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openPick.toggle()
            } label: {
                HStack(spacing: 8) {
                    CalIcon(size: 14, color: openPick ? Theme.bg : Theme.textDim)
                    Text(dateTileLabel)
                        .font(Fonts.sans(13, weight: .medium))
                        .foregroundColor(openPick ? Theme.bg : Theme.text)
                        .tracking(-0.1)
                    Spacer(minLength: 10)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(openPick ? Theme.text : Theme.surface2)
                )
                .hairlineBorder(openPick ? Theme.text : Theme.hairline, radius: 10)
            }
            .buttonStyle(.plain)

            if openPick {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { DateUtil.parseISO(value) ?? Date() },
                        set: { value = DateUtil.fmtISO($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(Theme.accent)
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .hairlineBorder(Theme.hairline, radius: 12)
            }
        }
    }

    private var dateTileLabel: String {
        guard let date = DateUtil.parseISO(value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func pill(active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Fonts.sans(13, weight: .medium))
                .foregroundColor(active ? Theme.bg : Theme.text)
                .tracking(-0.1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(active ? Theme.text : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(active ? Theme.text : Theme.hairline, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

struct TagEditor: View {
    @Binding var tags: [String]
    @State private var draft: String = ""
    @FocusState private var draftFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 5, runSpacing: 5) {
                ForEach(Array(tags.enumerated()), id: \.offset) { idx, tag in
                    TagChip(label: tag, onRemove: { remove(at: idx) })
                }
                TextField(
                    "",
                    text: $draft,
                    prompt: Text("add tag…")
                        .foregroundColor(Theme.textFaint)
                )
                .focused($draftFocused)
                .font(Fonts.mono(12))
                .foregroundColor(Theme.text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .frame(minWidth: 80)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .onSubmit { commitDraft() }
            }
            Text("↵ to add  ·  tap × to remove")
                .font(Fonts.mono(10))
                .foregroundColor(Theme.textFaint)
                .tracking(0.4)
        }
        .onChange(of: draft) { _, new in
            if new.contains(",") {
                draft = new.replacingOccurrences(of: ",", with: "")
                commitDraft()
            }
        }
    }

    private func commitDraft() {
        let t = draft.trimmingCharacters(in: .whitespaces)
        defer { draft = "" }
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
    }

    private func remove(at i: Int) {
        guard tags.indices.contains(i) else { return }
        tags.remove(at: i)
    }
}

struct EditorView: View {
    @ObservedObject var store: ThingsStore
    @State var thing: Thing
    let isNew: Bool
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    init(store: ThingsStore, initial: Thing, isNew: Bool, onClose: (() -> Void)? = nil) {
        self.store = store
        self._thing = State(initialValue: initial)
        self.isNew = isNew
        self.onClose = onClose
    }

    private var canSave: Bool {
        !thing.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky header
                HStack {
                    Button("Cancel") { close() }
                        .font(Fonts.sans(14, weight: .medium))
                        .foregroundColor(Theme.textDim)
                        .tracking(-0.1)
                        .buttonStyle(.plain)
                    Spacer()
                    Text(isNew ? "New thing" : "Edit")
                        .font(Fonts.display(15, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .tracking(-0.2)
                    Spacer()
                    Button(action: {
                        if canSave {
                            store.save(thing)
                            close()
                        }
                    }) {
                        Text("Save")
                            .font(Fonts.sans(13, weight: .semibold))
                            .foregroundColor(canSave ? Theme.bg : Theme.textFaint)
                            .tracking(-0.1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(canSave ? Theme.text : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(Theme.bg)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.hairlineSoft).frame(height: 0.5)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        FieldRow(label: "Title") {
                            HStack(alignment: .top, spacing: 10) {
                                TextField(
                                    "",
                                    text: $thing.name,
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
                                
                                Button(action: { thing.starred.toggle() }) {
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
                            onClear: { thing.date = nil }
                        ) {
                            if thing.date != nil {
                                DatePickerRow(value: Binding(
                                    get: { thing.date ?? DateUtil.fmtISO(Date()) },
                                    set: { thing.date = $0 }
                                ))
                            } else {
                                Button(action: { thing.date = DateUtil.fmtISO(Date()) }) {
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
                            optional: !thing.tags.isEmpty,
                            onClear: { thing.tags = [] }
                        ) {
                            TagEditor(tags: $thing.tags)
                        }

                        if !isNew {
                            Button(action: { confirmDelete = true }) {
                                HStack(spacing: 6) {
                                    TrashIcon(size: 13, color: Theme.danger)
                                    Text("DELETE")
                                        .font(Fonts.mono(11, weight: .medium))
                                        .foregroundColor(Theme.danger)
                                        .tracking(0.6)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if confirmDelete {
                ConfirmDialog(
                    title: "Delete this thing?",
                    message: "“\(thing.name)” will be removed. This can't be undone.",
                    confirmLabel: "Delete",
                    onConfirm: {
                        confirmDelete = false
                        store.delete(id: thing.id)
                        close()
                    },
                    onCancel: { confirmDelete = false }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if isNew {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    nameFocused = true
                }
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
