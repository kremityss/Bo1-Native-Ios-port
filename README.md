# BO1 Native iOS — engine foundation (source package 0.1.0)

**Status: partial engineering foundation, not a port of the original Black Ops game.**

An ahead-of-time-compiled native iOS Metal app design with no WebView or JIT dependence, together with Swift simulation, a glTF conversion utility, and PC game-folder inventory. **Original BO1 content and complete game logic are missing** and must be separately developed and sourced lawfully.

### What's in the foundation package
- iOS Metal renderer and landscape touch-control scaffolding.
- 60 Hz Swift gameplay simulation (movement, hitscan, cooldowns, magazines/reloads).
- Static glTF geometry converter to a compact native scene format.
- Original low-poly diagnostic test scene; no proprietary game assets.
- Read-only asset inventory utility and tests.
- macOS GitHub Actions unsigned build pipeline.

### Not implemented
- Original Black Ops 1 engine compatibility, T5 fastfile runtime loading, complete maps, collisions, animations, textures, audio and NPC navigation.
- BO1 campaign, Zombies, multiplayer, Combat Training bots, networking or DLC.
- Verified physical iPhone build, signed installable IPA or 60 FPS benchmark.

This project is not affiliated with Activision, Treyarch, Call of Duty or Plutonium. No proprietary game assets should be committed to this public repository.
