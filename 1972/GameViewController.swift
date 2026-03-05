//
//  GameViewController.swift
//  1972
//
//  Created by edwin kroon on 04/03/2026.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    private let textureNames = [
        "playerShip", "star1",
        "planet1", "planet2", "planet3", "planet4", "planet5", "planet6", "planet7",
        "rocket2", "bullet1", "bullet4", "enemy1", "alienplane", "endboss1",
        "powerup1", "powerup2", "powerup3", "powerup4", "powerup5"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        let skView: SKView
        if let v = view as? SKView {
            skView = v
        } else {
            skView = SKView(frame: view.bounds)
            skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(skView)
        }

        view.backgroundColor = .black
        skView.backgroundColor = SKColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true

        // Loading-indicator tonen; textures asynchroon preloaden, daarna scene op main thread presenteren
        let loading = UIActivityIndicatorView(style: .large)
        loading.color = .white
        loading.translatesAutoresizingMaskIntoConstraints = false
        loading.startAnimating()
        view.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        let textures = textureNames.map { SKTexture(imageNamed: $0) }
        SKTexture.preload(textures) { [weak self] in
            DispatchQueue.main.async {
                loading.removeFromSuperview()
                guard let self = self else { return }
                let scene = GameScene(size: skView.bounds.size)
                scene.scaleMode = .resizeFill
                skView.presentScene(scene)
            }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
