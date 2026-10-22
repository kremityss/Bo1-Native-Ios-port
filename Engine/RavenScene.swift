import Foundation
import simd

// On-disk RVNMAP01: eight ASCII bytes, uint32 vertex count, uint32 index count,
// followed by interleaved (float4 position, float4 color), then uint32 indices.
struct GPUVertex {
    var position: SIMD4<Float>
    var color: SIMD4<Float>
}

struct RavenScene {
    let vertices: [GPUVertex]
    let indices: [UInt32]

    static func load(from url: URL) throws -> RavenScene {
        let data = try Data(contentsOf: url)
        guard data.count >= 16, Array(data.prefix(8)) == Array("RVNMAP01".utf8) else {
            throw SceneError.invalidHeader
        }
        func u32(_ at: Int) -> UInt32 {
            UInt32(data[at]) | (UInt32(data[at+1]) << 8) |
            (UInt32(data[at+2]) << 16) | (UInt32(data[at+3]) << 24)
        }
        func f32(_ at: Int) -> Float { Float(bitPattern: u32(at)) }
        let nv = Int(u32(8)), ni = Int(u32(12))
        guard nv > 0, ni > 0, ni % 3 == 0, nv <= 20_000_000,
              ni <= 60_000_000,
              16 + nv * 32 + ni * 4 == data.count else {
            throw SceneError.invalidSize
        }
        var verts: [GPUVertex] = []; verts.reserveCapacity(nv)
        for i in 0..<nv {
            let o = 16 + i*32
            verts.append(GPUVertex(position: SIMD4(f32(o),f32(o+4),f32(o+8),f32(o+12)),
                                   color: SIMD4(f32(o+16),f32(o+20),f32(o+24),f32(o+28))))
        }
        var idx: [UInt32] = []; idx.reserveCapacity(ni)
        let start = 16 + nv*32
        for i in 0..<ni {
            let n = u32(start+i*4)
            guard Int(n) < nv else { throw SceneError.invalidIndex }
            idx.append(n)
        }
        return RavenScene(vertices: verts, indices: idx)
    }
}

enum SceneError: Error {
    case invalidHeader, invalidSize, invalidIndex
}
