import SwiftUI
import SwiftData

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

    private var simulation = ForceSimulation()
    private var viewSize: CGSize = .init(width: 390, height: 700)

    // MARK: - Build from SwiftData

    func rebuild(people: [Person]) {
        let filtered = people.filter { person in
            !person.interactions.filter { $0.timestamp >= dateRange.lowerBound && $0.timestamp <= dateRange.upperBound }.isEmpty
        }

        nodes = filtered.enumerated().map { idx, person in
            let count = person.interactions.filter {
                $0.timestamp >= dateRange.lowerBound && $0.timestamp <= dateRange.upperBound
            }.count
            let radius = Float(max(14, min(38, 10 + sqrt(Double(count)) * 6)))
            let color = colorForPerson(person)
            let angle = Float(idx) / Float(max(filtered.count, 1)) * 2 * .pi
            let spread: Float = 150
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

    private func colorForPerson(_ person: Person) -> SIMD4<Float> {
        switch person.dominantSentiment {
        case .secure:   return SIMD4<Float>(0.47, 0.78, 0.74, 1)
        case .anxious:  return SIMD4<Float>(0.93, 0.60, 0.57, 1)
        case .avoidant: return SIMD4<Float>(0.72, 0.72, 0.74, 1)
        case nil:
            switch person.relationshipType {
            case .closeFriend: return SIMD4<Float>(0.35, 0.68, 0.64, 1)
            case .romantic:    return SIMD4<Float>(0.93, 0.60, 0.57, 1)
            case .family:      return SIMD4<Float>(0.65, 0.82, 0.93, 1)
            case .friend:      return SIMD4<Float>(0.47, 0.78, 0.74, 1)
            case .acquaintance: return SIMD4<Float>(0.72, 0.72, 0.74, 1)
            }
        }
    }
}
