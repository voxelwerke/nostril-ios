import SwiftUI

struct Tukutuku: View {
    // --- State for Sliding ---
    @State private var offset: CGPoint = .zero
    @State private var baseOffset: CGPoint = .zero
    @State private var velocity: CGPoint = .zero
    
    // --- State for Roto-Zoom ---
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    @State private var baseRotation: Angle = .zero
    
    @State private var lastFrameDate: Date = .now
    
    // Config
    let tileSize: CGFloat = 35
    let friction: CGFloat = 0.96

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let deltaT = CGFloat(now.timeIntervalSince(lastFrameDate))
                
                // 1. Physics (Sliding Inertia)
                if abs(velocity.x) > 0.5 || abs(velocity.y) > 0.5 {
                    DispatchQueue.main.async {
                        offset.x += velocity.x * deltaT
                        offset.y += velocity.y * deltaT
                        velocity.x *= friction
                        velocity.y *= friction
                        lastFrameDate = now
                    }
                }

                // 2. Apply Roto-Zoom Transforms to the whole Canvas
                // We move to center, rotate/scale, then move back
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.rotate(by: rotation)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -size.width / 2, y: -size.height / 2)

                // 3. Infinite Tiling Logic
                // We draw a larger grid than needed to cover gaps during rotation
                let extraBuffer = 10
                let cols = Int(size.width / tileSize) + extraBuffer
                let rows = Int(size.height / tileSize) + extraBuffer
                
                let xShift = offset.x.truncatingRemainder(dividingBy: tileSize)
                let yShift = offset.y.truncatingRemainder(dividingBy: tileSize)

                for row in -extraBuffer...rows {
                    for col in -extraBuffer...cols {
                        let x = CGFloat(col) * tileSize - xShift
                        let y = CGFloat(row) * tileSize - yShift
                        
                        // World space indices for stable coloring
                        let worldCol = col + Int(floor(offset.x / tileSize))
                        let worldRow = row + Int(floor(offset.y / tileSize))
                        let isRed = (worldRow + worldCol) % 2 == 0
                        
                        drawCross(context: context, x: x, y: y, size: tileSize, isRed: isRed)
                    }
                }
            }
            .onAppear { lastFrameDate = timeline.date }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .gesture(
            // Combined Gesture: Drag + Magnify + Rotate
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    velocity = .zero
                    offset.x = baseOffset.x - value.translation.width
                    offset.y = baseOffset.y - value.translation.height
                }
                .onEnded { value in
                    velocity = CGPoint(x: -value.velocity.width, y: -value.velocity.height)
                    baseOffset = offset
                    lastFrameDate = .now
                }
            .simultaneously(with: MagnifyGesture()
                .onChanged { value in
                    scale = baseScale * value.magnification
                }
                .onEnded { _ in
                    baseScale = scale
                })
            .simultaneously(with: RotateGesture()
                .onChanged { value in
                    rotation = baseRotation + value.rotation
                }
                .onEnded { _ in
                    baseRotation = rotation
                })
        )
    }

    func drawCross(context: GraphicsContext, x: CGFloat, y: CGFloat, size: CGFloat, isRed: Bool) {
        let padding = size * 0.2
        let rect = CGRect(x: x + padding, y: y + padding, width: size - padding*2, height: size - padding*2)
        let color = isRed ? Color(red: 0.8, green: 0.2, blue: 0.1) : Color.white.opacity(0.8)
        
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
}
