import Foundation
import Metal
import MetalKit
import simd
import QuartzCore

private struct FrameUniforms {
    var mvp: simd_float4x4
}

final class MetalRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    private let indexCount: Int

    var simulation = GameSimulation()
    var input = InputFrame()
    var renderScale: Float = 0.8
    var onFrame: ((GameSimulation, Float) -> Void)?
    private var previous: CFTimeInterval = CACurrentMediaTime()
    private var accumulator: Float = 0
    private var frameCounter = 0
    private var fpsAccum: Float = 0
    private var fps: Float = 0

    init?(view: MTKView, scene: RavenScene) {
        guard let d = MTLCreateSystemDefaultDevice(),
              let q = d.makeCommandQueue(),
              let lib = d.makeDefaultLibrary(),
              let vf = lib.makeFunction(name: "raven_vertex"),
              let ff = lib.makeFunction(name: "raven_fragment") else { return nil }
        device = d
        queue = q
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vf
        descriptor.fragmentFunction = ff
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        guard let pl = try? d.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        pipeline = pl
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .less
        depth.isDepthWriteEnabled = true
        guard let ds = d.makeDepthStencilState(descriptor: depth) else { return nil }
        depthState = ds
        guard let vb = scene.vertices.withUnsafeBytes({ ptr in
            d.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: .storageModeShared)
        }), let ib = scene.indices.withUnsafeBytes({ ptr in
            d.makeBuffer(bytes: ptr.baseAddress!, length: ptr.count, options: .storageModeShared)
        }) else { return nil }
        vertexBuffer = vb
        indexBuffer = ib
        indexCount = scene.indices.count
        super.init()
        view.device = d
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.framebufferOnly = true
        view.delegate = self
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func draw(in view: MTKView) {
        let t = CACurrentMediaTime()
        let dt = Float(min(t - previous, 0.05))
        previous = t
        accumulator = min(accumulator + dt, 0.10)
        let oneStep: Float = 1.0 / 60.0
        // Prevent frame-dependent look sensitivity: consume gesture delta once.
        var perFrame = input
        input.yawDelta = 0; input.pitchDelta = 0
        let steps = min(6, Int(accumulator / oneStep))
        if steps > 0 {
            perFrame.yawDelta /= Float(steps)
            perFrame.pitchDelta /= Float(steps)
            for _ in 0..<steps {
                simulation.step(input: perFrame, dt: oneStep)
                accumulator -= oneStep
            }
        } else {
            input.yawDelta += perFrame.yawDelta
            input.pitchDelta += perFrame.pitchDelta
        }
        fpsAccum += dt; frameCounter += 1
        if fpsAccum > 0.45 {
            fps = Float(frameCounter) / fpsAccum
            fpsAccum = 0; frameCounter = 0
            onFrame?(simulation, fps)
        }
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        let aspect = Float(view.drawableSize.width / max(1.0, view.drawableSize.height))
        let projection = perspective(fov: Float.pi/2.8, aspect: aspect, near: 0.04, far: 2000)
        let eye = SIMD3<Float>(simulation.player.x, simulation.player.y, simulation.player.z)
        let cy = cos(simulation.yaw), sy = sin(simulation.yaw)
        let cp = cos(simulation.pitch), sp = sin(simulation.pitch)
        let direction = SIMD3<Float>(-sy*cp, sp, -cy*cp)
        let camera = lookAt(eye: eye, at: eye+direction, up: SIMD3(0,1,0))
        var uniform = FrameUniforms(mvp: projection * camera)
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniform, length: MemoryLayout<FrameUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount,
                                      indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    private func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1.0 / tan(fov/2)
        let x = y/aspect
        let z = far/(near-far)
        return simd_float4x4(columns: (
            SIMD4(x,0,0,0), SIMD4(0,y,0,0), SIMD4(0,0,z,-1), SIMD4(0,0,z*near,0)
        ))
    }

    private func lookAt(eye: SIMD3<Float>, at: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = simd_normalize(at-eye)
        let s = simd_normalize(simd_cross(f,up))
        let u = simd_cross(s,f)
        return simd_float4x4(columns: (
            SIMD4(s.x,u.x,-f.x,0),
            SIMD4(s.y,u.y,-f.y,0),
            SIMD4(s.z,u.z,-f.z,0),
            SIMD4(-simd_dot(s,eye),-simd_dot(u,eye),simd_dot(f,eye),1)
        ))
    }
}
