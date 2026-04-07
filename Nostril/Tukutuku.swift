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
    
    // --- Animation State ---
    @State private var lastFrameDate: Date = .now
    // Set to distantPast so (now - lastInteraction) > 5 seconds immediately on launch
    @State private var lastInteractionTime: Date = .distantPast
    @State private var isInteracting: Bool = false
    @State private var localTime: CGFloat = 0.0
    
    // Config
    let tileSize: CGFloat = 35
    let friction: CGFloat = 0.96
    let idleDelay: TimeInterval = 5.0
    let lerpSpeed: CGFloat = 0.03

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let deltaT = CGFloat(now.timeIntervalSince(lastFrameDate))
                let timeSinceTouch = now.timeIntervalSince(lastInteractionTime)
                
                // 1. Clock (Shader-style u_time)
                DispatchQueue.main.async {
                    localTime += deltaT
                    lastFrameDate = now
                }

                // 2. Physics (Inertia)
                if !isInteracting && (abs(velocity.x) > 0.5 || abs(velocity.y) > 0.5) {
                    DispatchQueue.main.async {
                        offset.x += velocity.x * deltaT
                        offset.y += velocity.y * deltaT
                        velocity.x *= friction
                        velocity.y *= friction
                    }
                }

                // 3. Target Math (The Sinusoidal "Original" State)
                let targetRotationRad = Double(localTime * 0.2)
                let targetScale = 1.0 + 0.2 * sin(localTime * 0.5)
                
                // 4. Return to Home / Auto-Animate Logic
                // This will run immediately because lastInteractionTime starts at .distantPast
                if !isInteracting && timeSinceTouch > idleDelay {
                    DispatchQueue.main.async {
                        // Smoothly mix toward the targets
                        let rDiff = targetRotationRad - rotation.radians
                        let smartDiff = atan2(sin(rDiff), cos(rDiff))
                        
                        rotation = Angle(radians: rotation.radians + smartDiff * Double(lerpSpeed))
                        scale = scale + (targetScale - scale) * lerpSpeed
                        
                        // Sync bases so gestures are seamless
                        baseRotation = rotation
                        baseScale = scale
                    }
                }

                // 5. Apply Canvas Transforms
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.rotate(by: rotation)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -size.width / 2, y: -size.height / 2)

                // 6. Draw Infinite Tiles
                let extraBuffer = 15
                let cols = Int(size.width / tileSize) + extraBuffer
                let rows = Int(size.height / tileSize) + extraBuffer
                
                let xShift = offset.x.truncatingRemainder(dividingBy: tileSize)
                let yShift = offset.y.truncatingRemainder(dividingBy: tileSize)

                for row in -extraBuffer...rows {
                    for col in -extraBuffer...cols {
                        let x = CGFloat(col) * tileSize - xShift
                        let y = CGFloat(row) * tileSize - yShift
                        
                        let worldCol = col + Int(floor(offset.x / tileSize))
                        let worldRow = row + Int(floor(offset.y / tileSize))
                        let isRed = (worldRow + worldCol) % 2 == 0
                        
                        drawCross(context: context, x: x, y: y, size: tileSize, isRed: isRed)
                    }
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isInteracting = true
                    velocity = .zero
                    offset.x = baseOffset.x - value.translation.width
                    offset.y = baseOffset.y - value.translation.height
                    lastInteractionTime = .now
                }
                .onEnded { value in
                    velocity = CGPoint(x: -value.velocity.width, y: -value.velocity.height)
                    baseOffset = offset
                    isInteracting = false
                }
            .simultaneously(with: MagnifyGesture()
                .onChanged { value in
                    isInteracting = true
                    scale = baseScale * value.magnification
                    lastInteractionTime = .now
                }
                .onEnded { _ in
                    baseScale = scale
                    isInteracting = false
                })
            .simultaneously(with: RotateGesture()
                .onChanged { value in
                    isInteracting = true
                    rotation = baseRotation + value.rotation
                    lastInteractionTime = .now
                }
                .onEnded { _ in
                    baseRotation = rotation
                    isInteracting = false
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
