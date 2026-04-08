import SwiftUI
import SwiftData
import simd

@Observable
final class GraphViewModel {

    // MARK: - Node / Edge types

    struct Node: Identifiable {
        let id: PersistentIdentifier
        var position: SIMD2<Float>
        var velocity: SIMD2<Float> = .zero
        var radius: Float
        var color: SIMD4<Float>
        var label: String
    }

    struct Edge {
        let sourceIndex: Int
        let targetIndex: Int
        var weight: Float
    }

    // MARK: - State

    var nodes: [Node] = []
    var edges: [Edge] = []
    var selectedPersonID: PersistentIdentifier? = nil
    var hoveredPersonID: PersistentIdentifier? = nil
    var dateRange: ClosedRange<Date> = Date.distantPast...Date.now
    var isPaused: Bool = false
    var panOffset: SIMD2<Float> = .zero
    var zoomScale: Float = 1.0

    private var simulation = ForceSimulation()
    var viewSize: CGSize = .init(width: 390, height: 700)

    // MARK: - Build from SwiftData

    func rebuild(people: [Person]) {
        let filtered = people.filter { person in
            !person.interactions.filter { $0.timestamp >= dateRange.lowerBound && $0.timestamp <= dateRange.upperBound }.isEmpty
        }

        nodes = filtered.enumerated().map { idx, person in
            let count = person.interactions.filter {
                $0.timestamp >= dateRange.lowerBound && $0.timestamp <= dateRange.upperBound
            }.count
            let radius = Float(max(50, min(95, 30 + sqrt(Double(count)) * 14)))
            let color = colorForIndex(idx)
            let angle = Float(idx) / Float(max(filtered.count, 1)) * 2 * .pi
            let spread: Float = 180
            let position = SIMD2<Float>(
                Float(viewSize.width / 2) + spread * cos(angle),
                Float(viewSize.height / 2) + spread * sin(angle)
            )
            return Node(id: person.persistentModelID, position: position, radius: radius, color: color, label: person.name)
        }

        // Build edges from group interactions logged on same day
        var edgeMap: [String: Float] = [:]
        let groupInteractions = filtered.flatMap { p in
            p.interactions.filter {
                ($0.locationContext == .smallGroup || $0.locationContext == .largeGroup)
                && $0.timestamp >= dateRange.lowerBound && $0.timestamp <= dateRange.upperBound
            }.map { (p, $0) }
        }

        let calendar = Calendar.current
        for i in 0..<filtered.count {
            for j in (i+1)..<filtered.count {
                let personA = filtered[i]
                let personB = filtered[j]
                let datesA = Set(groupInteractions.filter { $0.0 === personA }.map { calendar.startOfDay(for: $0.1.timestamp) })
                let datesB = Set(groupInteractions.filter { $0.0 === personB }.map { calendar.startOfDay(for: $0.1.timestamp) })
                let shared = datesA.intersection(datesB).count
                if shared > 0 {
                    let key = "\(i)-\(j)"
                    edgeMap[key] = Float(shared)
                }
            }
        }

        edges = edgeMap.compactMap { key, weight in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return Edge(sourceIndex: parts[0], targetIndex: parts[1], weight: weight)
        }
    }

    // MARK: - Simulation step

    func step(dt: Float) {
        guard !isPaused, !nodes.isEmpty else { return }
        let center = SIMD2<Float>(Float(viewSize.width / 2), Float(viewSize.height / 2))
        simulation.step(nodes: &nodes, edges: edges, dt: dt, center: center)
    }

    func setViewSize(_ size: CGSize) {
        viewSize = size
    }

    // MARK: - Hit testing

    func nodeAt(point: CGPoint, viewSize: CGSize) -> Node? {
        let p = SIMD2<Float>(Float(point.x), Float(point.y))
        return nodes.first { node in
            simd_distance(node.position, p) <= node.radius * 1.3
        }
    }

    // MARK: - Color helpers

    private static let nodePalette: [SIMD4<Float>] = [
        SIMD4<Float>(0.25, 0.72, 0.68, 1), // teal
        SIMD4<Float>(0.94, 0.38, 0.38, 1), // red
        SIMD4<Float>(0.58, 0.34, 0.92, 1), // violet
        SIMD4<Float>(0.98, 0.62, 0.12, 1), // amber
        SIMD4<Float>(0.22, 0.54, 0.97, 1), // blue
        SIMD4<Float>(0.22, 0.80, 0.46, 1), // green
        SIMD4<Float>(0.97, 0.35, 0.72, 1), // pink
        SIMD4<Float>(0.98, 0.82, 0.12, 1), // yellow
        SIMD4<Float>(0.12, 0.78, 0.90, 1), // cyan
        SIMD4<Float>(0.96, 0.50, 0.25, 1), // orange
    ]

    private func colorForIndex(_ idx: Int) -> SIMD4<Float> {
        Self.nodePalette[idx % Self.nodePalette.count]
    }
}
