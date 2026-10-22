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
        print("PASS: weapon cadence, reload, movement, hitscan, collision-ray tests")
    }
}
