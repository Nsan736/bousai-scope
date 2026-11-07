import SwiftUI

/// 方位の目盛りと、印の方向を示す矢印。端末の上端の向きが、常に上になる。
struct ScopeCompassDial: View {
    let heading: Double
    let targets: [ScopeTarget]

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 26
            func position(_ degrees: Double, _ r: CGFloat) -> CGPoint {
                let rad = (degrees - heading) * .pi / 180
                return CGPoint(x: center.x + r * CGFloat(sin(rad)), y: center.y - r * CGFloat(cos(rad)))
            }
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Color.secondary.opacity(0.5)), lineWidth: 1)
            // 10度ごとの目盛り(30度ごとは長く)
            var minor = Path()
            var major = Path()
            for degrees in stride(from: 0.0, to: 360, by: 10) {
                let isMajor = Int(degrees) % 30 == 0
                let from = position(degrees, radius - (isMajor ? 12 : 6))
                let to = position(degrees, radius)
                if isMajor {
                    major.move(to: from)
                    major.addLine(to: to)
                } else {
                    minor.move(to: from)
                    minor.addLine(to: to)
                }
            }
            context.stroke(minor, with: .color(Color.secondary.opacity(0.6)), lineWidth: 1)
            context.stroke(major, with: .color(.primary), lineWidth: 1.5)
            for (degrees, name) in [(0.0, "北"), (90.0, "東"), (180.0, "南"), (270.0, "西")] {
                let text = Text(name).font(.system(size: 16, weight: .bold)).foregroundColor(degrees == 0 ? .red : .primary)
                context.draw(text, at: position(degrees, radius - 26))
            }
            // 端末の向き(上が正面)
            var pointer = Path()
            pointer.move(to: CGPoint(x: center.x, y: center.y - radius - 20))
            pointer.addLine(to: CGPoint(x: center.x - 8, y: center.y - radius - 4))
            pointer.addLine(to: CGPoint(x: center.x + 8, y: center.y - radius - 4))
            pointer.closeSubpath()
            context.fill(pointer, with: .color(.primary))
            // 印の方向の矢印(遠いものから描く)。電車は、方向の位置に、進行方向の矢印の入った印を置く。
            for target in targets {
                let color = target.mark.color
                if let travel = target.mark.travelHeading {
                    let spot = position(target.bearing, radius - 40)
                    let rect = CGRect(x: spot.x - 11, y: spot.y - 11, width: 22, height: 22)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    context.stroke(Path(ellipseIn: rect), with: .color(.primary), lineWidth: 1.5)
                    let rad = (travel - heading) * .pi / 180
                    let direction = CGPoint(x: CGFloat(sin(rad)), y: -CGFloat(cos(rad)))
                    let normal = CGPoint(x: -direction.y, y: direction.x)
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: spot.x + direction.x * 8, y: spot.y + direction.y * 8))
                    arrow.addLine(to: CGPoint(x: spot.x - direction.x * 5 + normal.x * 5, y: spot.y - direction.y * 5 + normal.y * 5))
                    arrow.addLine(to: CGPoint(x: spot.x - direction.x * 5 - normal.x * 5, y: spot.y - direction.y * 5 - normal.y * 5))
                    arrow.closeSubpath()
                    context.fill(arrow, with: .color(.white))
                    continue
                }
                let tip = position(target.bearing, radius - 40)
                var shaft = Path()
                shaft.move(to: center)
                shaft.addLine(to: tip)
                context.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                let rad = (target.bearing - heading) * .pi / 180
                let direction = CGPoint(x: CGFloat(sin(rad)), y: -CGFloat(cos(rad)))
                let normal = CGPoint(x: -direction.y, y: direction.x)
                var head = Path()
                head.move(to: CGPoint(x: tip.x + direction.x * 12, y: tip.y + direction.y * 12))
                head.addLine(to: CGPoint(x: tip.x + normal.x * 7, y: tip.y + normal.y * 7))
                head.addLine(to: CGPoint(x: tip.x - normal.x * 7, y: tip.y - normal.y * 7))
                head.closeSubpath()
                context.fill(head, with: .color(color))
                context.stroke(head, with: .color(.primary), lineWidth: 1)
            }
            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(.primary))
        }
    }
}
