import SwiftUI
import UIKit

struct DetailView: View {
    @ObservedObject var store: ThingsStore
    let thingID: Int
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete = false
    @State private var draft = Thing(id: -1, name: "", date: nil, tags: [], starred: false)
    @FocusState private var nameFocused: Bool

    private var thing: Thing? { store.things.first(where: { $0.id == thingID }) }

    private var hasChanges: Bool {
        guard let thing else { return false }
        return draft == thing ? false : draft.id == thing.id
    }

    private var canSave: Bool {
        hasChanges && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Button(action: saveDraft) {
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
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    ScrollView {
                        editorBody(thing: draft.id == thing.id ? draft : thing)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                    }
                    .scrollBounceBehavior(.basedOnSize)
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
        .enableSwipeBack()
        .onAppear {
            syncDraftIfNeeded()
        }
    }

    @ViewBuilder
    private func editorBody(thing: Thing) -> some View {
        let b = Binding<Thing>(
            get: { draft.id == thing.id ? draft : thing },
            set: { draft = $0 }
        )

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
                    .textContentType(.none)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .strikethrough(thing.completed, color: Theme.textFaint)
                    
                    Button(action: {
                        var next = b.wrappedValue
                        next.starred.toggle()
                        b.wrappedValue = next
                    }) {
                        StarIcon(
                            filled: b.wrappedValue.starred,
                            size: 22,
                            color: b.wrappedValue.starred ? Theme.accent : Theme.textFaint
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
                    ), quickChoices: !thing.completed)
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
                TagEditor(
                    tags: b.tags,
                    suggestions: store.topTags(limit: 5, excluding: Set(b.wrappedValue.tags))
                )
            }

            VStack(spacing: 10) {
                Button {
                    var next = b.wrappedValue
                    if next.completed {
                        next.completed = false
                        next.completedAt = nil
                    } else {
                        next.completed = true
                        next.completedAt = Date()
                    }
                    b.wrappedValue = next
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: b.wrappedValue.completed ? "arrow.uturn.backward" : "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                        Text(b.wrappedValue.completed ? "MARK ACTIVE" : "MARK DONE")
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

    private func syncDraftIfNeeded() {
        guard let thing, draft.id != thing.id else { return }
        draft = thing
    }

    private func saveDraft() {
        guard canSave else { return }
        store.save(draft)
        store.showToast("Changes saved")
    }
}

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = controller.navigationController else {
                return
            }

            context.coordinator.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

private extension View {
    func enableSwipeBack() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0))
    }
}
