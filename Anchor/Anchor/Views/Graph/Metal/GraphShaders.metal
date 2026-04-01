#include <metal_stdlib>
using namespace metal;

// MARK: - Shared types

struct TransformUniforms {
    float4x4 transform;
};

// MARK: - Node shaders

struct NodeVertexIn {
    float2 position  [[attribute(0)]];
    float2 uv        [[attribute(1)]];
    float4 color     [[attribute(2)]];
    float  radius    [[attribute(3)]];
    uint   selected  [[attribute(4)]];
};

struct NodeVertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    uint   selected;
};

vertex NodeVertexOut nodeVertex(
    NodeVertexIn in [[stage_in]],
    constant TransformUniforms& uniforms [[buffer(1)]]
) {
    NodeVertexOut out;
    float4 worldPos = float4(in.position, 0.0, 1.0);
    out.position = uniforms.transform * worldPos;
    out.uv = in.uv;
    out.color = in.color;
    out.selected = in.selected;
    return out;
}

fragment float4 nodeFragment(NodeVertexOut in [[stage_in]]) {
    float dist = length(in.uv);

    // Discard outside circle
    if (dist > 1.0) discard_fragment();

    float alpha = 1.0;

    // Soft anti-aliased edge
    float edgeWidth = 0.08;
    alpha *= smoothstep(1.0, 1.0 - edgeWidth, dist);

    // Inner ring for selected state
    if (in.selected > 0) {
        float innerDist = abs(dist - 0.82);
        float ringAlpha = 1.0 - smoothstep(0.0, 0.08, innerDist);
        float4 ringColor = float4(1.0, 1.0, 1.0, ringAlpha * 0.8);
        return mix(in.color * float4(1,1,1,alpha), ringColor, ringAlpha);
    }

    // Subtle radial gradient for depth
    float brightness = 1.0 + (1.0 - dist) * 0.15;
    return float4(in.color.rgb * min(brightness, 1.2), in.color.a * alpha);
}

// MARK: - Edge shaders

struct EdgeVertexIn {
    float2 position [[attribute(0)]];
    float  alpha    [[attribute(1)]];
};

struct EdgeVertexOut {
    float4 position [[position]];
    float  alpha;
};

vertex EdgeVertexOut edgeVertex(
    EdgeVertexIn in [[stage_in]],
    constant TransformUniforms& uniforms [[buffer(1)]]
) {
    EdgeVertexOut out;
    out.position = uniforms.transform * float4(in.position, 0.0, 1.0);
    out.alpha = in.alpha;
    return out;
}

fragment float4 edgeFragment(EdgeVertexOut in [[stage_in]]) {
    return float4(0.5, 0.5, 0.55, in.alpha * 0.35);
}

// MARK: - Label background shaders (simple rect)

struct LabelVertexIn {
    float2 position [[attribute(0)]];
};

struct LabelVertexOut {
    float4 position [[position]];
};

vertex LabelVertexOut labelVertex(
    LabelVertexIn in [[stage_in]],
    constant TransformUniforms& uniforms [[buffer(1)]]
) {
    LabelVertexOut out;
    out.position = uniforms.transform * float4(in.position, 0.0, 1.0);
    return out;
}

fragment float4 labelFragment(LabelVertexOut in [[stage_in]]) {
    return float4(0.0, 0.0, 0.0, 0.45);
}
