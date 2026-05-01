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

    private var canReorderQuery: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if store.active.isEmpty && query.isEmpty {
                EmptyHomeState()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        headerView
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)

                        ForEach(groups) { g in
                            VStack(alignment: .leading, spacing: 8) {
                                DateHeader(iso: g.date, count: g.items.count)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 18)
                                    .padding(.top, 8)

                                ReorderableSection(
                                    items: g.items,
                                    canReorder: canReorderQuery && g.items.count > 1,
                                    onTap: { selectedThingID = $0 },
                                    onToggleStar: { store.toggleStar(id: $0) },
                                    onComplete: { id in
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                            store.markCompleted(id: id)
                                        }
                                    },
                                    onCommitOrder: { ids in
                                        store.setOrder(ids)
                                    }
                                )
                            }
                        }

                        if filtered.isEmpty && !query.isEmpty {
                            Text("No things match \u{201C}\(query)\u{201D}")
                                .font(Fonts.display(15))
                                .foregroundColor(Theme.textFaint)
                                .tracking(-0.2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                        }

                        Color.clear.frame(height: 60)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
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

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("Things")
                    .font(Fonts.display(28, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .tracking(-0.8)
                Spacer()
                Text("\(todayCount) today \u{00B7} \(starredCount) starred")
                    .font(Fonts.mono(11))
                    .foregroundColor(Theme.textFaint)
                    .tracking(0.4)
            }
            SearchBar(query: $query)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Reorderable section

private struct ReorderableSection: View {
    let items: [Thing]
    let canReorder: Bool
    let onTap: (Int) -> Void
    let onToggleStar: (Int) -> Void
    let onComplete: (Int) -> Void
    let onCommitOrder: ([Int]) -> Void

    @State private var draggingID: Int?
    @State private var dragTranslation: CGFloat = 0
    @State private var displayItems: [Thing] = []
    @State private var rowHeights: [Int: CGFloat] = [:]
    @State private var swipeOffsets: [Int: CGFloat] = [:]
    @State private var swipingID: Int?

    @State private var activationHaptic = UIImpactFeedbackGenerator(style: .medium)
    @State private var swapHaptic = UIImpactFeedbackGenerator(style: .light)
    @State private var completeHaptic = UINotificationFeedbackGenerator()

    private let spacing: CGFloat = 8
    private let swipeCommitThreshold: CGFloat = 96
    private let swipeMaxReveal: CGFloat = 140

    private var rendered: [Thing] {
        draggingID != nil ? displayItems : items
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rendered) { item in
                rowView(for: item)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .onPreferenceChange(RowHeightKey.self) { dict in
            for (k, v) in dict { rowHeights[k] = v }
        }
        .onChange(of: items) { _, _ in
            if draggingID == nil {
                displayItems = []
            }
        }
    }

    @ViewBuilder
    private func rowView(for item: Thing) -> some View {
        let isDragging = draggingID == item.id
        let swipeOffset = swipeOffsets[item.id] ?? 0
        let revealing = swipeOffset < -1

        ZStack(alignment: .trailing) {
            if revealing {
                completeBackdrop(progress: min(abs(swipeOffset) / swipeCommitThreshold, 1))
            }

            ThingCard(
                thing: item,
                onTap: {
                    if draggingID == nil && abs(swipeOffset) < 2 {
                        onTap(item.id)
                    }
                },
                onToggleStar: { onToggleStar(item.id) },
                showReorderHandle: canReorder
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: RowHeightKey.self,
                        value: [item.id: geo.size.height]
                    )
                }
            )
            .offset(x: swipeOffset)
        }
        .scaleEffect(isDragging ? 1.035 : 1)
        .shadow(
            color: Color.black.opacity(isDragging ? 0.38 : 0),
            radius: isDragging ? 18 : 0,
            x: 0,
            y: isDragging ? 12 : 0
        )
        .offset(y: isDragging ? dragTranslation : 0)
        .zIndex(isDragging ? 2 : 0)
        .gesture(reorderGesture(for: item), including: canReorder ? .all : .subviews)
        .simultaneousGesture(swipeGesture(for: item))
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: rendered.map(\.id))
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.9), value: isDragging)
    }

    private func completeBackdrop(progress: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.accent.opacity(0.85 * progress + 0.15))
            .overlay(
                HStack {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .opacity(progress)
                        .padding(.trailing, 24)
                }
            )
    }

    // MARK: - Reorder gesture

    private func reorderGesture(for item: Thing) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginDrag(for: item.id)
                case .second(true, let drag):
                    if draggingID != item.id {
                        beginDrag(for: item.id)
                    }
                    if let drag {
                        dragTranslation = drag.translation.height
                        checkForSwap(of: item.id)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in
                if draggingID == item.id {
                    endDrag()
                }
            }
    }

    private func beginDrag(for id: Int) {
        guard draggingID != id else { return }
        displayItems = items
        draggingID = id
        dragTranslation = 0
        activationHaptic.prepare()
        activationHaptic.impactOccurred(intensity: 0.75)
        swapHaptic.prepare()
    }

    private func endDrag() {
        let finalOrder = displayItems.map(\.id)
        let originalOrder = items.map(\.id)
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
            draggingID = nil
            dragTranslation = 0
        }
        if finalOrder != originalOrder {
            onCommitOrder(finalOrder)
        }
        // Hold the local snapshot until items[] catches up so positions don't flicker.
    }

    private func checkForSwap(of id: Int) {
        guard let idx = displayItems.firstIndex(where: { $0.id == id }) else { return }

        if dragTranslation < 0, idx > 0 {
            let neighborID = displayItems[idx - 1].id
            let neighborHeight = rowHeights[neighborID] ?? 64
            let threshold = -(neighborHeight + spacing) / 2
            if dragTranslation < threshold {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86)) {
                    displayItems.swapAt(idx, idx - 1)
                }
                dragTranslation += (neighborHeight + spacing)
                swapHaptic.impactOccurred(intensity: 0.65)
                swapHaptic.prepare()
            }
        } else if dragTranslation > 0, idx < displayItems.count - 1 {
            let neighborID = displayItems[idx + 1].id
            let neighborHeight = rowHeights[neighborID] ?? 64
            let threshold = (neighborHeight + spacing) / 2
            if dragTranslation > threshold {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86)) {
                    displayItems.swapAt(idx, idx + 1)
                }
                dragTranslation -= (neighborHeight + spacing)
                swapHaptic.impactOccurred(intensity: 0.65)
                swapHaptic.prepare()
            }
        }
    }

    // MARK: - Swipe-to-complete gesture

    private func swipeGesture(for item: Thing) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard draggingID == nil else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                // Only react to predominantly horizontal, leftward motion.
                guard swipingID == item.id || (abs(dx) > abs(dy) * 1.4 && dx < 0) else { return }
                swipingID = item.id
                swipeOffsets[item.id] = max(min(dx, 0), -swipeMaxReveal)
            }
            .onEnded { value in
                guard swipingID == item.id else { return }
                swipingID = nil
                let dx = value.translation.width
                if draggingID == nil && dx < -swipeCommitThreshold {
                    completeHaptic.notificationOccurred(.success)
                    onComplete(item.id)
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    swipeOffsets[item.id] = 0
                }
            }
    }
}

private struct RowHeightKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Search & empty state

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
