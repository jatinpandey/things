import SwiftUI

struct StarIcon: View {
    var filled: Bool
    var size: CGFloat = 18
    var color: Color = Theme.accent

    var body: some View {
        StarShape()
            .fill(filled ? color : Color.clear)
            .overlay(
                StarShape().stroke(color, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            )
            .frame(width: size, height: size)
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [
            (12, 2.5), (14.9, 8.8), (21.8, 9.5), (16.6, 14.2),
            (18.1, 21), (12, 17.6), (5.9, 21), (7.4, 14.2),
            (2.2, 9.5), (9.1, 8.8), (12, 2.5)
        ]
        var p = Path()
        let sx = rect.width / 24
        let sy = rect.height / 24
        for (i, (x, y)) in pts.enumerated() {
            let pt = CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct PlusIcon: View {
    var size: CGFloat = 22
    var color: Color = .white
    var body: some View {
        ZStack {
            Capsule().fill(color).frame(width: size * 0.58, height: size * 0.10)
            Capsule().fill(color).frame(width: size * 0.10, height: size * 0.58)
        }
        .frame(width: size, height: size)
    }
}

struct BackIcon: View {
    var size: CGFloat = 22
    var color: Color = Theme.text
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 15, y: 5))
            p.addLine(to: CGPoint(x: 8, y: 12))
            p.addLine(to: CGPoint(x: 15, y: 19))
        }
        .applying(CGAffineTransform(scaleX: size/24, y: size/24))
        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

struct CloseIcon: View {
    var size: CGFloat = 20
    var color: Color = Theme.text
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 6, y: 6))
                p.addLine(to: CGPoint(x: 18, y: 18))
                p.move(to: CGPoint(x: 18, y: 6))
                p.addLine(to: CGPoint(x: 6, y: 18))
            }
            .applying(CGAffineTransform(scaleX: size/24, y: size/24))
            .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct CalIcon: View {
    var size: CGFloat = 18
    var color: Color = Theme.textDim
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5 * size/24, style: .continuous)
                .stroke(color, lineWidth: 1.6 * size/24)
                .frame(width: 17 * size/24, height: 15 * size/24)
                .offset(y: 1 * size/24)
            Path { p in
                p.move(to: CGPoint(x: 3.5, y: 9.5))
                p.addLine(to: CGPoint(x: 20.5, y: 9.5))
                p.move(to: CGPoint(x: 8, y: 3))
                p.addLine(to: CGPoint(x: 8, y: 7))
                p.move(to: CGPoint(x: 16, y: 3))
                p.addLine(to: CGPoint(x: 16, y: 7))
            }
            .applying(CGAffineTransform(scaleX: size/24, y: size/24))
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct TrashIcon: View {
    var size: CGFloat = 18
    var color: Color = Theme.danger
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 4, y: 7));  p.addLine(to: CGPoint(x: 20, y: 7))
            p.move(to: CGPoint(x: 9, y: 7));  p.addLine(to: CGPoint(x: 9, y: 4)); p.addLine(to: CGPoint(x: 15, y: 4)); p.addLine(to: CGPoint(x: 15, y: 7))
            p.move(to: CGPoint(x: 6, y: 7));  p.addLine(to: CGPoint(x: 7, y: 20)); p.addLine(to: CGPoint(x: 17, y: 20)); p.addLine(to: CGPoint(x: 18, y: 7))
            p.move(to: CGPoint(x: 10, y: 11)); p.addLine(to: CGPoint(x: 10, y: 17))
            p.move(to: CGPoint(x: 14, y: 11)); p.addLine(to: CGPoint(x: 14, y: 17))
        }
        .applying(CGAffineTransform(scaleX: size/24, y: size/24))
        .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

struct SearchIcon: View {
    var size: CGFloat = 18
    var color: Color = Theme.textFaint
    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1.8 * size/24)
                .frame(width: 13 * size/24, height: 13 * size/24)
                .offset(x: -1.5 * size/24, y: -1.5 * size/24)
            Path { p in
                p.move(to: CGPoint(x: 15.5, y: 15.5))
                p.addLine(to: CGPoint(x: 20, y: 20))
            }
            .applying(CGAffineTransform(scaleX: size/24, y: size/24))
            .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}
