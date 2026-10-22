import Foundation

/// v1 sidecar for a converted RVN scene. Generated/hand-authored data, NOT a T5 parser.
/// Camera position is eye-height in world meters. All colliders are world-space AABBs.
struct LevelManifest: Decodable {
    let schemaVersion: Int
    let name: String
    let playerSpawn: [Float]
    let boxes: [BoxRecord]
    let targets: [BoxRecord]

    struct BoxRecord: Decodable {
        let min: [Float]
        let max: [Float]

        func asAABB() throws -> AABB {
            guard min.count == 3, max.count == 3,
                  min.allSatisfy({ $0.isFinite && abs($0) < 100_000 }),
                  max.allSatisfy({ $0.isFinite && abs($0) < 100_000 }),
                  (0..<3).allSatisfy({ min[$0] <= max[$0] }) else {
                throw LevelError.invalidBounds
            }
            return AABB(min: V3(min[0], min[1], min[2]), max: V3(max[0], max[1], max[2]))
        }
    }

    enum LevelError: Error { case invalidVersion, invalidSpawn, invalidBounds, tooManyObjects }

    func makeSimulation() throws -> GameSimulation {
        guard schemaVersion == 1 else { throw LevelError.invalidVersion }
        guard playerSpawn.count == 3,
              playerSpawn.allSatisfy({ $0.isFinite && abs($0) < 100_000 }) else {
            throw LevelError.invalidSpawn
        }
        guard boxes.count <= 65_536, targets.count <= 4096 else { throw LevelError.tooManyObjects }
        let worldBoxes = try boxes.map { try $0.asAABB() }
        let worldTargets = try targets.map { HitTarget(bounds: try $0.asAABB()) }
        var simulation = GameSimulation()
        simulation.player = V3(playerSpawn[0], playerSpawn[1], playerSpawn[2])
        simulation.obstacles = worldBoxes
        simulation.targets = worldTargets
        return simulation
    }
}
