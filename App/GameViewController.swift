import Foundation
import UIKit
import MetalKit

final class GameViewController: UIViewController {
    private var metalView: MTKView!
    private var renderer: MetalRenderer?
    private let hud = UILabel()
    private var levelName = "Test range"

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let metal = MTKView(frame: view.bounds)
        metal.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metal.autoResizeDrawable = false
        view.addSubview(metal)
        metalView = metal
        if let url = Bundle.main.url(forResource: "scene", withExtension: "rvn") ??
                     Bundle.main.url(forResource: "demo", withExtension: "rvn"),
           let scene = try? RavenScene.load(from: url) {
            renderer = MetalRenderer(view: metal, scene: scene)
        }
        if let renderer {
            let sceneName = Bundle.main.url(forResource: "scene", withExtension: "rvn") != nil ? "scene" : "demo"
            if let metaURL = Bundle.main.url(forResource: sceneName, withExtension: "level.json"),
               let data = try? Data(contentsOf: metaURL),
               let level = try? JSONDecoder().decode(LevelManifest.self, from: data),
               let world = try? level.makeSimulation() {
                renderer.simulation = world
                levelName = level.name
            } else if sceneName == "scene" {
                // Never silently reuse the sample-range collision in an imported map.
                renderer.simulation.obstacles = []
                renderer.simulation.targets = []
                levelName = "Scene preview (no collision sidecar)"
            }
        }
        if renderer == nil {
            let label = UILabel(frame: view.bounds)
            label.text = "Metal or scene data unavailable — check the build logs"
            label.textAlignment = .center
            label.textColor = .white
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(label)
            return
        }
        installControls()
        renderer?.onFrame = { [weak self] sim, fps in
            self?.hud.text = String(format: "%@  |  %.0f FPS  |  %d / %d  |  Hits %d", self?.levelName ?? "Level", fps,
                                    sim.weapon.magazine, sim.weapon.reserve, sim.hits)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = CGFloat(renderer?.renderScale ?? 0.8) * UIScreen.main.scale
        metalView?.drawableSize = CGSize(width: max(1, view.bounds.width * scale),
                                         height: max(1, view.bounds.height * scale))
    }

    private func installControls() {
        hud.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        hud.textColor = UIColor.white.withAlphaComponent(0.90)
        hud.textAlignment = .left
        hud.text = "NATIVE METAL  |  loading..."
        hud.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])
        let left = UIView(); left.backgroundColor = .clear; left.translatesAutoresizingMaskIntoConstraints = false
        let right = UIView(); right.backgroundColor = .clear; right.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(left); view.addSubview(right)
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: view.leadingAnchor), left.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            left.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45),
            left.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.78),
            right.trailingAnchor.constraint(equalTo: view.trailingAnchor), right.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            right.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.55),
            right.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.78)
        ])
        let stick = UIPanGestureRecognizer(target: self, action: #selector(moveStick(_:)))
        stick.maximumNumberOfTouches = 1
        left.addGestureRecognizer(stick)
        let look = UIPanGestureRecognizer(target: self, action: #selector(lookAround(_:)))
        look.maximumNumberOfTouches = 1
        right.addGestureRecognizer(look)
        let moveLabel = UILabel(); moveLabel.text = "MOVE"; moveLabel.textColor = .white.withAlphaComponent(0.3)
        moveLabel.translatesAutoresizingMaskIntoConstraints = false; left.addSubview(moveLabel)
        NSLayoutConstraint.activate([moveLabel.leadingAnchor.constraint(equalTo: left.leadingAnchor, constant: 32),
                                     moveLabel.bottomAnchor.constraint(equalTo: left.bottomAnchor, constant: -40)])
        let centerMark = UILabel(); centerMark.text = "+"; centerMark.textColor = .white
        centerMark.font = .systemFont(ofSize: 27, weight: .light); centerMark.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerMark)
        NSLayoutConstraint.activate([centerMark.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     centerMark.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        let fire = makeButton("FIRE"); let reload = makeButton("RELOAD"); let sprint = makeButton("SPRINT")
        fire.addTarget(self, action: #selector(fireOn), for: .touchDown)
        fire.addTarget(self, action: #selector(fireOff), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        reload.addTarget(self, action: #selector(reloadPress), for: .touchDown)
        sprint.addTarget(self, action: #selector(sprintOn), for: .touchDown)
        sprint.addTarget(self, action: #selector(sprintOff), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        view.addSubview(fire); view.addSubview(reload); view.addSubview(sprint)
        NSLayoutConstraint.activate([
            fire.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            fire.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            fire.widthAnchor.constraint(equalToConstant: 76), fire.heightAnchor.constraint(equalToConstant: 68),
            reload.trailingAnchor.constraint(equalTo: fire.leadingAnchor, constant: -12),
            reload.bottomAnchor.constraint(equalTo: fire.bottomAnchor),
            reload.widthAnchor.constraint(equalToConstant: 80), reload.heightAnchor.constraint(equalToConstant: 50),
            sprint.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            sprint.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            sprint.widthAnchor.constraint(equalToConstant: 82), sprint.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func makeButton(_ name: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(name, for: .normal); b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 12)
        b.backgroundColor = UIColor.black.withAlphaComponent(0.40)
        b.layer.cornerRadius = 14
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    @objc private func moveStick(_ pan: UIPanGestureRecognizer) {
        guard let renderer else { return }
        if pan.state == .ended || pan.state == .cancelled {
            renderer.input.lateral = 0; renderer.input.forward = 0
        } else {
            let offset = pan.translation(in: pan.view)
            renderer.input.lateral = Float(max(-1, min(1, offset.x/70)))
            renderer.input.forward = Float(max(-1, min(1, -offset.y/70)))
        }
    }
    @objc private func lookAround(_ pan: UIPanGestureRecognizer) {
        guard let renderer else { return }
        let delta = pan.translation(in: pan.view)
        renderer.input.yawDelta += Float(delta.x) * 0.005
        renderer.input.pitchDelta -= Float(delta.y) * 0.005
        pan.setTranslation(.zero, in: pan.view)
    }
    @objc private func fireOn() { renderer?.input.shoot = true }
    @objc private func fireOff() { renderer?.input.shoot = false }
    @objc private func reloadPress() {
        guard let renderer else { return }
        _ = renderer.simulation.weapon.reload()
    }
    @objc private func sprintOn() { renderer?.input.sprint = true }
    @objc private func sprintOff() { renderer?.input.sprint = false }
}
