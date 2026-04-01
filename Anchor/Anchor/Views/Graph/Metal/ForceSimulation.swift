import Foundation
import simd

struct ForceSimulation {
    var dampingFactor: Float = 0.95
    var centerGravity: Float = 0.003
    var repulsionStrength: Float = 900
    var springStiffness: Float = 0.035
    var maxVelocity: Float = 60

    // MARK: - Main step

    mutating func step(nodes: inout [GraphViewModel.Node], edges: [GraphViewModel.Edge], dt: Float, center: SIMD2<Float>) {
        guard nodes.count > 1 else { return }

        var forces = [SIMD2<Float>](repeating: .zero, count: nodes.count)

        // 1. Repulsion (Barnes-Hut approximation)
        let tree = QuadTree(nodes: nodes)
        for i in nodes.indices {
            forces[i] += tree.repulsiveForce(on: nodes[i], strength: repulsionStrength, theta: 0.9)
        }

        // 2. Spring attraction along edges
        for edge in edges {
            guard edge.sourceIndex < nodes.count, edge.targetIndex < nodes.count else { continue }
            let a = nodes[edge.sourceIndex]
            let b = nodes[edge.targetIndex]
            let diff = b.position - a.position
            let dist = max(simd_length(diff), 0.01)
            let restLength = (a.radius + b.radius) * 2.5
            let displacement = dist - restLength
            let springForce = springStiffness * displacement * edge.weight
            let direction = diff / dist
            forces[edge.sourceIndex] += direction * springForce
            forces[edge.targetIndex] -= direction * springForce
        }

        // 3. Center gravity
        for i in nodes.indices {
            let toCenter = center - nodes[i].position
            forces[i] += toCenter * centerGravity
        }

        // 4. Integrate + damp
        for i in nodes.indices {
            nodes[i].velocity = (nodes[i].velocity + forces[i] * dt) * dampingFactor
            // Clamp velocity
            let speed = simd_length(nodes[i].velocity)
            if speed > maxVelocity {
                nodes[i].velocity = nodes[i].velocity / speed * maxVelocity
            }
            nodes[i].position += nodes[i].velocity * dt

            // Guard against NaN
            if nodes[i].position.x.isNaN || nodes[i].position.y.isNaN {
                nodes[i].position = center
                nodes[i].velocity = .zero
            }
        }
    }
}

// MARK: - Barnes-Hut Quad Tree

private struct QuadTree {
    struct Bounds {
        var minX, minY, maxX, maxY: Float
        var midX: Float { (minX + maxX) / 2 }
        var midY: Float { (minY + maxY) / 2 }
        var width: Float { maxX - minX }
        var height: Float { maxY - minY }
    }

    indirect enum NodeContent {
        case empty
        case leaf(index: Int, position: SIMD2<Float>, mass: Float)
        case branch(children: [QuadTree?], centerOfMass: SIMD2<Float>, totalMass: Float)
    }

    let bounds: Bounds
    var content: NodeContent = .empty

    init(nodes: [GraphViewModel.Node]) {
        guard !nodes.isEmpty else {
            self.bounds = Bounds(minX: 0, minY: 0, maxX: 1, maxY: 1)
            return
        }
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        let pad: Float = 50
        self.bounds = Bounds(
            minX: (xs.min() ?? 0) - pad,
            minY: (ys.min() ?? 0) - pad,
            maxX: (xs.max() ?? 1) + pad,
            maxY: (ys.max() ?? 1) + pad
        )
        for (idx, node) in nodes.enumerated() {
            insert(index: idx, position: node.position, mass: node.radius)
        }
    }

    private init(bounds: Bounds) {
        self.bounds = bounds
    }

    mutating func insert(index: Int, position: SIMD2<Float>, mass: Float) {
        switch content {
        case .empty:
            content = .leaf(index: index, position: position, mass: mass)

        case .leaf(let existingIndex, let existingPos, let existingMass):
            // Split into branch
            var children: [QuadTree?] = [nil, nil, nil, nil]
            let childBounds = quadrantBounds()

            var child0 = QuadTree(bounds: childBounds[0])
            child0.insert(index: existingIndex, position: existingPos, mass: existingMass)
            children[quadrantIndex(for: existingPos)] = child0

            let newQuad = quadrantIndex(for: position)
            if children[newQuad] == nil {
                children[newQuad] = QuadTree(bounds: childBounds[newQuad])
            }
            children[newQuad]!.insert(index: index, position: position, mass: mass)

            let com = (existingPos * existingMass + position * mass) / (existingMass + mass)
            content = .branch(children: children, centerOfMass: com, totalMass: existingMass + mass)

        case .branch(var children, let com, let totalMass):
            let q = quadrantIndex(for: position)
            if children[q] == nil {
                let childBounds = quadrantBounds()
                children[q] = QuadTree(bounds: childBounds[q])
            }
            children[q]!.insert(index: index, position: position, mass: mass)
            let newCom = (com * totalMass + position * mass) / (totalMass + mass)
            content = .branch(children: children, centerOfMass: newCom, totalMass: totalMass + mass)
        }
    }

    func repulsiveForce(on node: GraphViewModel.Node, strength: Float, theta: Float) -> SIMD2<Float> {
        switch content {
        case .empty:
            return .zero
        case .leaf(let idx, let pos, let mass):
            // Skip self
            if simd_distance(pos, node.position) < 0.01 { return .zero }
            return force(from: pos, mass: mass, to: node.position, strength: strength)
        case .branch(let children, let com, let totalMass):
            let dist = simd_distance(com, node.position)
            let size = max(bounds.width, bounds.height)
            if dist > 0 && size / dist < theta {
                // Treat as single body
                return force(from: com, mass: totalMass, to: node.position, strength: strength)
            }
            return children.reduce(SIMD2<Float>.zero) { acc, child in
                acc + (child?.repulsiveForce(on: node, strength: strength, theta: theta) ?? .zero)
            }
        }
    }

    private func force(from source: SIMD2<Float>, mass: Float, to target: SIMD2<Float>, strength: Float) -> SIMD2<Float> {
        let diff = target - source
        let dist = max(simd_length(diff), 1.0)
        let magnitude = strength * mass / (dist * dist)
        return (diff / dist) * magnitude
    }

    private func quadrantIndex(for pos: SIMD2<Float>) -> Int {
        let right = pos.x >= bounds.midX
        let bottom = pos.y >= bounds.midY
        return (bottom ? 2 : 0) + (right ? 1 : 0)
    }

    private func quadrantBounds() -> [Bounds] {
        [
            Bounds(minX: bounds.minX, minY: bounds.minY, maxX: bounds.midX, maxY: bounds.midY),
            Bounds(minX: bounds.midX, minY: bounds.minY, maxX: bounds.maxX, maxY: bounds.midY),
            Bounds(minX: bounds.minX, minY: bounds.midY, maxX: bounds.midX, maxY: bounds.maxY),
            Bounds(minX: bounds.midX, minY: bounds.midY, maxX: bounds.maxX, maxY: bounds.maxY),
        ]
    }
}
