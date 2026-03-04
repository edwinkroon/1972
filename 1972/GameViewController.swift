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
        
        if let view = self.view as! SKView? {
            // Create game scene with fixed portrait size (1942-style shooter)
            let scene = GameScene(size: CGSize(width: 1536, height: 2048))
            scene.scaleMode = .aspectFill
            view.presentScene(scene)

            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
