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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Zorg dat we een SKView hebben (storyboard heeft vaak gewone UIView → dan geen scene = zwart)
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

        // Scene grootte = view grootte, zodat alles binnen het zichtbare scherm blijft (geen aspectFill-crop)
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
