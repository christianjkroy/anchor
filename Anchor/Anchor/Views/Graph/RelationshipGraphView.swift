import SwiftUI
import MetalKit
import SwiftData

struct RelationshipGraphView: UIViewRepresentable {
    var viewModel: GraphViewModel
    var onNodeTapped: (PersistentIdentifier) -> Void
    var onNodeLongPressed: (PersistentIdentifier, CGPoint) -> Void

    static var isMetalAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Metal unavailable (e.g. some simulators) — return inert view
            let fallback = MTKView()
            fallback.backgroundColor = UIColor.systemBackground
            return fallback
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.clearColor = MTLClearColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.backgroundColor = UIColor.systemBackground

        let renderer = GraphRenderer(device: device)
        context.coordinator.renderer = renderer
        mtkView.delegate = renderer

        // Gestures
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))

        mtkView.addGestureRecognizer(tap)
        mtkView.addGestureRecognizer(longPress)
        mtkView.addGestureRecognizer(pan)
        mtkView.addGestureRecognizer(pinch)

        // Display link drives simulation
        let displayLink = CADisplayLink(target: context.coordinator, selector: #selector(Coordinator.displayLinkFired))
        displayLink.add(to: .main, forMode: .common)
        context.coordinator.displayLink = displayLink

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onNodeTapped: onNodeTapped, onNodeLongPressed: onNodeLongPressed)
    }

    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        coordinator.displayLink?.invalidate()
        coordinator.displayLink = nil
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var viewModel: GraphViewModel
        var renderer: GraphRenderer?
        var displayLink: CADisplayLink?
        var onNodeTapped: (PersistentIdentifier) -> Void
        var onNodeLongPressed: (PersistentIdentifier, CGPoint) -> Void
        private var lastFrameTime: CFTimeInterval = 0
        private var panStart: SIMD2<Float> = .zero
        private var basePanOffset: SIMD2<Float> = .zero

        init(viewModel: GraphViewModel, onNodeTapped: @escaping (PersistentIdentifier) -> Void, onNodeLongPressed: @escaping (PersistentIdentifier, CGPoint) -> Void) {
            self.viewModel = viewModel
            self.onNodeTapped = onNodeTapped
            self.onNodeLongPressed = onNodeLongPressed
        }

        @objc func displayLinkFired() {
            let now = CACurrentMediaTime()
            let dt = lastFrameTime == 0 ? 1/60.0 : min(now - lastFrameTime, 0.05)
            lastFrameTime = now

            viewModel.step(dt: Float(dt))

            renderer?.nodes = viewModel.nodes
            renderer?.edges = viewModel.edges
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let point = recognizer.location(in: view)
            if let node = viewModel.nodeAt(point: point, viewSize: view.bounds.size) {
                HapticFeedback.light()
                onNodeTapped(node.id)
            }
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let view = recognizer.view else { return }
            let point = recognizer.location(in: view)
            if let node = viewModel.nodeAt(point: point, viewSize: view.bounds.size) {
                HapticFeedback.medium()
                viewModel.hoveredPersonID = node.id
                onNodeLongPressed(node.id, point)
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            switch recognizer.state {
            case .began:
                basePanOffset = renderer?.panOffset ?? .zero
            case .changed:
                let newOffset = basePanOffset + SIMD2<Float>(Float(translation.x), Float(translation.y))
                renderer?.panOffset = newOffset
                viewModel.panOffset = newOffset
            default:
                break
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard recognizer.state == .changed else { return }
            let current = renderer?.zoomScale ?? 1.0
            let newScale = max(0.3, min(3.0, current * Float(recognizer.scale)))
            renderer?.zoomScale = newScale
            viewModel.zoomScale = newScale
            recognizer.scale = 1.0
        }
    }
}
