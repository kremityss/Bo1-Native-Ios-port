#include <metal_stdlib>
using namespace metal;
struct GPUVertex {
    float4 position;
    float4 color;
};
struct FrameUniforms { float4x4 mvp; };
struct RasterOut {
    float4 position [[position]];
    float4 color;
};
vertex RasterOut raven_vertex(uint vertexId [[vertex_id]],
                             const device GPUVertex* verts [[buffer(0)]],
                             constant FrameUniforms& frame [[buffer(1)]]) {
    RasterOut output;
    output.position = frame.mvp * verts[vertexId].position;
    output.color = verts[vertexId].color;
    return output;
}
fragment float4 raven_fragment(RasterOut input [[stage_in]]) {
    return input.color;
}
