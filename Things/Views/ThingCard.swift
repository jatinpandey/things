import SwiftUI

struct TagChip: View {
    let label: String
    var accent: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(Fonts.mono(11, weight: .medium))
                .foregroundColor(accent ? Theme.accent : Theme.textDim)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Text("×")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textFaint)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .padding(.trailing, -3)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent ? Theme.accentDim : Theme.surface2)
        )
        .hairlineBorder(accent ? Theme.accentBorder : Theme.hairline, radius: 6)
    }
}

struct ThingCard: View {
    let thing: Thing
    var onTap: (() -> Void)? = nil
    var onToggleStar: () -> Void

    var body: some View {
        if let onTap {
            Button(action: onTap) { cardBody }.buttonStyle(.plain)
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 9) {
                Text(thing.name)
                    .font(Fonts.display(16, weight: .medium))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.35 * 16 - 16)
                    .strikethrough(thing.completed, color: Theme.textFaint)

                if !thing.tags.isEmpty {
                    FlowLayout(spacing: 4, runSpacing: 4) {
                        ForEach(Array(thing.tags.enumerated()), id: \.offset) { _, tag in
                            TagChip(label: tag)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggleStar) {
                StarIcon(filled: thing.starred,
                         size: 18,
                         color: thing.starred ? Theme.accent : Theme.textFaint)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .padding(-4)
        }
        .padding(14)
        .background(
            ZStack {
                if thing.starred {
                    LinearGradient(
                        colors: [Theme.accentTintTop, Theme.accentTintBot],
                        startPoint: .top, endPoint: .bottom
                    )
                } else {
                    Theme.surface
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .hairlineBorder(thing.starred ? Theme.accentBorderStrong : Theme.hairline, radius: 12)
        .overlay(alignment: .leading) {
            if thing.starred {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 2)
                    .padding(.vertical, 12)
            }
        }
    }
}

struct DateHeader: View {
    let iso: String
    let count: Int

    var body: some View {
        let isUntimed = iso == "—"
        let isToday = !isUntimed && DateUtil.daysFromToday(iso) == 0
        let isPast  = !isUntimed && DateUtil.daysFromToday(iso) < 0
        let label   = isUntimed ? "Untimed" : DateUtil.dayLabel(iso)

        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(Fonts.display(15, weight: .semibold))
                .foregroundColor(isToday ? Theme.text : Theme.textDim)
                .tracking(-0.2)
            if isUntimed {
                Text("· \(count)")
                    .font(Fonts.mono(10))
                    .foregroundColor(Theme.textFaint)
                    .tracking(0.4)
            } else {
                let meta = DateUtil.dayMeta(iso)
                Text("\(meta.month) \(meta.day) · \(count)")
                    .font(Fonts.mono(10))
                    .foregroundColor(Theme.textFaint)
                    .tracking(0.4)
            }
            Spacer()
            if isToday {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
        .padding(.bottom, 6)
        .opacity(isPast ? 0.55 : 1)
    }
}
