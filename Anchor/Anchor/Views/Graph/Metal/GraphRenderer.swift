import Metal
import MetalKit
import simd

// MARK: - Vertex types (must match shader structs)

struct NodeVertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
    var color: SIMD4<Float>
    var radius: Float
    var selected: UInt32
}

struct EdgeVertex {
    var position: SIMD2<Float>
    var alpha: Float
}

// MARK: - Renderer

final class GraphRenderer: NSObject, MTKViewDelegate {

    // Public state updated by RelationshipGraphView's coordinator
    var nodes: [GraphViewModel.Node] = []
    var edges: [GraphViewModel.Edge] = []
    var selectedNodeIndex: Int? = nil
    var panOffset: SIMD2<Float> = .zero
    var zoomScale: Float = 1.0

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var nodePipeline: MTLRenderPipelineState?
    private var edgePipeline: MTLRenderPipelineState?
    private var viewportSize: CGSize = .zero

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        super.init()
        buildPipelines()
    }

    // MARK: - Pipeline setup

    private func buildPipelines() {
        guard let library = device.makeDefaultLibrary() else { return }

        // Node pipeline
        let nodeDesc = MTLRenderPipelineDescriptor()
        nodeDesc.label = "Node Pipeline"
        nodeDesc.vertexFunction = library.makeFunction(name: "nodeVertex")
        nodeDesc.fragmentFunction = library.makeFunction(name: "nodeFragment")
        nodeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        nodeDesc.colorAttachments[0].isBlendingEnabled = true
        nodeDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        nodeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        nodeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        nodeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let nodeVertexDesc = MTLVertexDescriptor()
        nodeVertexDesc.attributes[0].format = .float2; nodeVertexDesc.attributes[0].offset = 0; nodeVertexDesc.attributes[0].bufferIndex = 0
        nodeVertexDesc.attributes[1].format = .float2; nodeVertexDesc.attributes[1].offset = 8; nodeVertexDesc.attributes[1].bufferIndex = 0
        nodeVertexDesc.attributes[2].format = .float4; nodeVertexDesc.attributes[2].offset = 16; nodeVertexDesc.attributes[2].bufferIndex = 0
        nodeVertexDesc.attributes[3].format = .float; nodeVertexDesc.attributes[3].offset = 32; nodeVertexDesc.attributes[3].bufferIndex = 0
        nodeVertexDesc.attributes[4].format = .uint; nodeVertexDesc.attributes[4].offset = 36; nodeVertexDesc.attributes[4].bufferIndex = 0
        nodeVertexDesc.layouts[0].stride = MemoryLayout<NodeVertex>.stride
        nodeDesc.vertexDescriptor = nodeVertexDesc

        // Edge pipeline
        let edgeDesc = MTLRenderPipelineDescriptor()
        edgeDesc.label = "Edge Pipeline"
        edgeDesc.vertexFunction = library.makeFunction(name: "edgeVertex")
        edgeDesc.fragmentFunction = library.makeFunction(name: "edgeFragment")
        edgeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        edgeDesc.colorAttachments[0].isBlendingEnabled = true
        edgeDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        edgeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        let edgeVertexDesc = MTLVertexDescriptor()
        edgeVertexDesc.attributes[0].format = .float2; edgeVertexDesc.attributes[0].offset = 0; edgeVertexDesc.attributes[0].bufferIndex = 0
        edgeVertexDesc.attributes[1].format = .float; edgeVertexDesc.attributes[1].offset = 8; edgeVertexDesc.attributes[1].bufferIndex = 0
        edgeVertexDesc.layouts[0].stride = MemoryLayout<EdgeVertex>.stride
        edgeDesc.vertexDescriptor = edgeVertexDesc

        nodePipeline = try? device.makeRenderPipelineState(descriptor: nodeDesc)
        edgePipeline = try? device.makeRenderPipelineState(descriptor: edgeDesc)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    func draw(in view: MTKView) {
        guard
            let nodePipeline,
            let edgePipeline,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let descriptor = view.currentRenderPassDescriptor,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
            let drawable = view.currentDrawable
        else { return }

        let transform = projectionMatrix(viewportSize: view.drawableSize)

        // Draw edges
        if !edges.isEmpty {
            let edgeVerts = buildEdgeVertices()
            if !edgeVerts.isEmpty, let buf = device.makeBuffer(bytes: edgeVerts, length: edgeVerts.count * MemoryLayout<EdgeVertex>.stride, options: .storageModeShared) {
                encoder.setRenderPipelineState(edgePipeline)
                encoder.setVertexBuffer(buf, offset: 0, index: 0)
                var t = transform
                encoder.setVertexBytes(&t, length: MemoryLayout<float4x4>.size, index: 1)
                encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeVerts.count)
            }
        }

        // Draw nodes
        if !nodes.isEmpty {
            let (nodeVerts, indices) = buildNodeVertices()
            if !nodeVerts.isEmpty,
               let vBuf = device.makeBuffer(bytes: nodeVerts, length: nodeVerts.count * MemoryLayout<NodeVertex>.stride, options: .storageModeShared),
               let iBuf = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared) {
                encoder.setRenderPipelineState(nodePipeline)
                encoder.setVertexBuffer(vBuf, offset: 0, index: 0)
                var t = transform
                encoder.setVertexBytes(&t, length: MemoryLayout<float4x4>.size, index: 1)
                encoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: iBuf, indexBufferOffset: 0)
            }
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Geometry builders

    private func buildNodeVertices() -> ([NodeVertex], [UInt16]) {
        var verts: [NodeVertex] = []
        var indices: [UInt16] = []

        for (i, node) in nodes.enumerated() {
            let isSelected = selectedNodeIndex == i ? UInt32(1) : UInt32(0)
            let pos = node.position + panOffset

            let base = UInt16(verts.count)
            let uvs: [SIMD2<Float>] = [
                SIMD2<Float>(-1, -1),
                SIMD2<Float>( 1, -1),
                SIMD2<Float>(-1,  1),
                SIMD2<Float>( 1,  1)
            ]
            for uv in uvs {
                verts.append(NodeVertex(
                    position: pos + uv * node.radius,
                    uv: uv,
                    color: node.color,
                    radius: node.radius,
                    selected: isSelected
                ))
            }
            // Two triangles: TL-TR-BL and TR-BR-BL
            indices += [base, base+1, base+2, base+1, base+3, base+2]
        }
        return (verts, indices)
    }

    private func buildEdgeVertices() -> [EdgeVertex] {
        var verts: [EdgeVertex] = []
        for edge in edges {
            guard edge.sourceIndex < nodes.count, edge.targetIndex < nodes.count else { continue }
            let a = nodes[edge.sourceIndex].position + panOffset
            let b = nodes[edge.targetIndex].position + panOffset
            let alpha = min(edge.weight / 5.0, 1.0)
            verts.append(EdgeVertex(position: a, alpha: alpha))
            verts.append(EdgeVertex(position: b, alpha: alpha))
        }
        return verts
    }

    // MARK: - Projection matrix

    private func projectionMatrix(viewportSize: CGSize) -> float4x4 {
        let w = Float(viewportSize.width)
        let h = Float(viewportSize.height)
        guard w > 0, h > 0 else { return matrix_identity_float4x4 }

        let sx = zoomScale * 2 / w
        let sy = zoomScale * -2 / h
        let tx = panOffset.x * sx - 1
        let ty = panOffset.y * sy + 1

        return float4x4(columns: (
            SIMD4<Float>(sx,  0,  0, 0),
            SIMD4<Float>( 0, sy,  0, 0),
            SIMD4<Float>( 0,  0,  1, 0),
            SIMD4<Float>(tx, ty,  0, 1)
        ))
    }
}
