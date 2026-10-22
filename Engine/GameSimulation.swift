import Foundation

// Portable, deterministic game logic. No UIKit, Metal or runtime JIT.
struct V3: Equatable {
    var x: Float; var y: Float; var z: Float
    init(_ x: Float, _ y: Float, _ z: Float) { self.x = x; self.y = y; self.z = z }
    static func + (a: V3, b: V3) -> V3 { V3(a.x+b.x, a.y+b.y, a.z+b.z) }
    static func - (a: V3, b: V3) -> V3 { V3(a.x-b.x, a.y-b.y, a.z-b.z) }
    static func * (a: V3, s: Float) -> V3 { V3(a.x*s, a.y*s, a.z*s) }
}

struct AABB {
    let min: V3; let max: V3
    func contains(_ p: V3, radius: Float = 0) -> Bool {
        p.x >= min.x-radius && p.x <= max.x+radius &&
        p.y >= min.y-radius && p.y <= max.y+radius &&
        p.z >= min.z-radius && p.z <= max.z+radius
    }
    // Slab ray intersection, parametric t on the normalized direction.
    func rayDistance(origin: V3, direction: V3, maxDistance: Float) -> Float? {
        var tMin: Float = 0; var tMax = maxDistance
        let o = [origin.x, origin.y, origin.z]
        let d = [direction.x, direction.y, direction.z]
        let mn = [min.x, min.y, min.z]
        let mx = [max.x, max.y, max.z]
        for a in 0..<3 {
            if abs(d[a]) < 0.000001 {
                if o[a] < mn[a] || o[a] > mx[a] { return nil }
            } else {
                let one = 1 / d[a]
                let ta = (mn[a]-o[a])*one
                let tb = (mx[a]-o[a])*one
                tMin = Swift.max(tMin, Swift.min(ta, tb))
                tMax = Swift.min(tMax, Swift.max(ta, tb))
                if tMax < tMin { return nil }
            }
        }
        return tMin
    }
}

struct WeaponState {
    // Placeholder tuning values, NOT recovered BO1 weapon data.
    var magazine: Int = 30
    var reserve: Int = 120
    var capacity: Int = 30
    var roundsPerMinute: Float = 600
    var reloadSeconds: Float = 2.2
    private(set) var cooldown: Float = 0
    private(set) var reloadRemaining: Float = 0
    var isReloading: Bool { reloadRemaining > 0 }
    mutating func update(_ dt: Float) {
        cooldown = max(0, cooldown - dt)
        if reloadRemaining > 0 {
            reloadRemaining -= dt
            if reloadRemaining <= 0 {
                reloadRemaining = 0
                let received = min(capacity-magazine, reserve)
                magazine += received; reserve -= received
            }
        }
    }
    mutating func fire() -> Bool {
        if isReloading || cooldown > 0 || magazine <= 0 { return false }
        magazine -= 1
        cooldown = 60 / max(roundsPerMinute, 1)
        return true
    }
    mutating func reload() -> Bool {
        if isReloading || magazine >= capacity || reserve == 0 { return false }
        reloadRemaining = reloadSeconds
        return true
    }
}

struct InputFrame {
    var lateral: Float = 0  // -1..1
    var forward: Float = 0  // -1..1
    var yawDelta: Float = 0
    var pitchDelta: Float = 0
    var sprint: Bool = false
    var shoot: Bool = false
    var reload: Bool = false
}

struct HitTarget {
    var bounds: AABB
    var health: Float = 100
}

struct GameSimulation {
    var player = V3(0, 1.65, 4)
    var yaw: Float = 0
    var pitch: Float = 0
    var weapon = WeaponState()
    // Matches the original diagnostic geometry, not recovered BO1 map collision.
    var obstacles: [AABB] = [
        AABB(min: V3(-16.25, 0, -27), max: V3(-15.75, 4, 23)),
        AABB(min: V3(15.75, 0, -27), max: V3(16.25, 4, 23)),
        AABB(min: V3(-16, 0, -27.25), max: V3(16, 4, -26.75)),
        AABB(min: V3(-5.5, 0, -12), max: V3(-2.5, 1.5, -10)),
        AABB(min: V3(4, 0, -15.5), max: V3(6, 2, -12.5))
    ]
    var targets: [HitTarget] = [
        HitTarget(bounds: AABB(min: V3(-0.5, 0, -6), max: V3(0.5, 2, -5)))
    ]
    var shotsFired = 0
    var hits = 0
    var elapsed: Float = 0

    mutating func step(input: InputFrame, dt: Float) {
        guard dt > 0 && dt < 0.25 else { return }
        elapsed += dt
        weapon.update(dt)
        yaw += input.yawDelta
        pitch = max(-1.35, min(1.35, pitch + input.pitchDelta))
        let speed: Float = input.sprint ? 6.0 : 3.4
        var x = max(-1, min(1, input.lateral))
        var z = max(-1, min(1, input.forward))
        let length = sqrt(x*x+z*z)
        if length > 1 { x /= length; z /= length }
        let displacement = V3((cos(yaw)*x - sin(yaw)*z)*speed*dt, 0,
                              (-sin(yaw)*x - cos(yaw)*z)*speed*dt)
        var candidate = player
        candidate.x += displacement.x
        if !obstacles.contains(where: { $0.contains(candidate, radius: 0.3) }) { player.x = candidate.x }
        candidate = player
        candidate.z += displacement.z
        if !obstacles.contains(where: { $0.contains(candidate, radius: 0.3) }) { player.z = candidate.z }
        if input.reload { _ = weapon.reload() }
        if input.shoot && weapon.fire() {
            shotsFired += 1
            let d = V3(-sin(yaw)*cos(pitch), sin(pitch), -cos(yaw)*cos(pitch))
            var nearest = Float.greatestFiniteMagnitude
            var targetIndex: Int? = nil
            for i in targets.indices where targets[i].health > 0 {
                if let t = targets[i].bounds.rayDistance(origin: player, direction: d, maxDistance: 100), t < nearest {
                    nearest = t; targetIndex = i
                }
            }
            let coverDistance = obstacles.compactMap { $0.rayDistance(origin: player, direction: d, maxDistance: 100) }.min() ?? 101
            if let i = targetIndex, nearest < coverDistance { targets[i].health -= 25; hits += 1 }
        }
    }
}
