import Foundation

@main enum Tests {
    static func main() {
        var w = WeaponState()
        assert(w.fire() && w.magazine == 29)
        assert(!w.fire(), "rate limiting")
        w.update(0.1)
        assert(w.fire())
        assert(w.reload())
        w.update(2.3)
        assert(w.magazine == 30 && w.reserve == 118)
        var g = GameSimulation()
        var input = InputFrame(); input.forward = 1
        g.step(input: input, dt: 0.1)
        assert(g.player.z < 4)
        var shot = InputFrame(); shot.shoot = true
        g.step(input: shot, dt: 0.2)
        assert(g.hits == 1 && g.targets[0].health == 75)
        let box = AABB(min: V3(-1, -1, -2), max: V3(1, 1, -1))
        assert(box.rayDistance(origin: V3(0,0,0), direction: V3(0,0,-1), maxDistance: 10) == 1)
        assert(box.rayDistance(origin: V3(3,0,0), direction: V3(0,0,-1), maxDistance: 10) == nil)
        let sample = """
        {"schemaVersion":1,"name":"Test","playerSpawn":[0,1.65,8],
         "boxes":[{"min":[-1,0,0],"max":[1,3,1]}],
         "targets":[{"min":[-0.5,0,-5],"max":[0.5,2,-4]}]}
        """
        let level = try! JSONDecoder().decode(LevelManifest.self, from: Data(sample.utf8))
        var custom = try! level.makeSimulation()
        assert(custom.player.z == 8 && custom.obstacles.count == 1 && custom.targets.count == 1)
        let blocked = """
        {"schemaVersion":1,"name":"Invalid","playerSpawn":[0,0,0],
         "boxes":[{"min":[1,0,0],"max":[0,3,1]}],"targets":[]}
        """
        let invalid = try! JSONDecoder().decode(LevelManifest.self, from: Data(blocked.utf8))
        assert((try? invalid.makeSimulation()) == nil, "invalid bounds must not load")
        var movement = InputFrame(); movement.forward = 1
        custom.step(input: movement, dt: 1.0/60.0)
        assert(custom.player.z < 8, "custom spawn must drive movement")
        print("PASS: level metadata validation, spawn, collision sidecar")
        print("PASS: weapon cadence, reload, movement, hitscan, collision-ray tests")
    }
}
