//
//  GameScene.swift
//  1972
//
//  1942/1943 vertical shooter. Touch drag left/right, hold to shoot. Enemy bullets.
//

import SpriteKit
import GameplayKit

// Physics categories
private let categoryPlayer:       UInt32 = 0x1 << 0
private let categoryEnemy:        UInt32 = 0x1 << 1
private let categoryPlayerBullet: UInt32 = 0x1 << 2
private let categoryEnemyBullet:  UInt32 = 0x1 << 3

private let maxPlayerBullets = 5
private let playerBulletSize = CGSize(width: 10, height: 20)
private let playerFireInterval: TimeInterval = 0.12
private let enemyBulletSize = CGSize(width: 8, height: 16)
private let enemyFireInterval: TimeInterval = 3.0

class GameScene: SKScene, SKPhysicsContactDelegate {

    private var player: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0
    private var lastSpawnTime: TimeInterval = 0
    private let spawnInterval: TimeInterval = 2.0
    private var touchLocationX: CGFloat?
    private var gameOver = false
    private var lastPlayerFireTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.15, alpha: 1)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // Player (green rect 50x40) – bottom center
        let playerSize = CGSize(width: 50, height: 40)
        player = SKSpriteNode(color: .green, size: playerSize)
        player.position = CGPoint(x: size.width / 2, y: 80)
        player.name = "player"
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = false
        player.physicsBody?.categoryBitMask = categoryPlayer
        player.physicsBody?.contactTestBitMask = categoryEnemy | categoryEnemyBullet
        player.physicsBody?.collisionBitMask = 0
        addChild(player)

        // Score label – rechtsboven
        scoreLabel = SKLabelNode(fontNamed: "Avenir-Bold")
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - 60, y: size.height - 60)
        scoreLabel.zPosition = 100
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !gameOver else { return }
        touchLocationX = touches.first?.location(in: self).x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !gameOver else { return }
        touchLocationX = touches.first?.location(in: self).x
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchLocationX = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchLocationX = nil
    }

    override func update(_ currentTime: TimeInterval) {
        guard !gameOver else { return }

        // Move player with touch drag (left/right)
        if let x = touchLocationX {
            let half = player.size.width / 2
            let clampedX = max(half, min(size.width - half, x))
            player.position.x = clampedX
        }

        // Player fire on touch hold – max 5 bullets
        if touchLocationX != nil, currentTime - lastPlayerFireTime >= playerFireInterval {
            let count = children.filter { $0.name == "playerBullet" }.count
            if count < maxPlayerBullets {
                lastPlayerFireTime = currentTime
                firePlayerBullet()
            }
        }

        // Enemy spawn timer – elke 2 sec
        if currentTime - lastSpawnTime > spawnInterval {
            lastSpawnTime = currentTime
            spawnEnemy()
        }
    }

    private func firePlayerBullet() {
        let bullet = SKSpriteNode(color: .white, size: playerBulletSize)
        bullet.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height / 2 + bullet.size.height / 2)
        bullet.name = "playerBullet"
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.isDynamic = false
        bullet.physicsBody?.categoryBitMask = categoryPlayerBullet
        bullet.physicsBody?.contactTestBitMask = categoryEnemy
        bullet.physicsBody?.collisionBitMask = 0
        addChild(bullet)

        let move = SKAction.moveTo(y: size.height + bullet.size.height, duration: 0.6)
        let remove = SKAction.removeFromParent()
        bullet.run(SKAction.sequence([move, remove]))
    }

    private func fireEnemyBullet(from enemy: SKSpriteNode) {
        guard enemy.parent != nil else { return }
        let bullet = SKSpriteNode(color: .yellow, size: enemyBulletSize)
        bullet.position = CGPoint(x: enemy.position.x, y: enemy.position.y - enemy.size.height / 2 - bullet.size.height / 2)
        bullet.name = "enemyBullet"
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.isDynamic = false
        bullet.physicsBody?.categoryBitMask = categoryEnemyBullet
        bullet.physicsBody?.contactTestBitMask = categoryPlayer
        bullet.physicsBody?.collisionBitMask = 0
        addChild(bullet)

        let move = SKAction.moveTo(y: -bullet.size.height, duration: 2.0)
        let remove = SKAction.removeFromParent()
        bullet.run(SKAction.sequence([move, remove]))
    }

    private func spawnEnemy() {
        let enemySize = CGSize(width: 60, height: 40)
        let enemy = SKSpriteNode(color: .red, size: enemySize)
        let margin: CGFloat = 60
        let x = CGFloat.random(in: margin...(size.width - margin))
        enemy.position = CGPoint(x: x, y: size.height + enemy.size.height)
        enemy.name = "enemy"
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.isDynamic = false
        enemy.physicsBody?.categoryBitMask = categoryEnemy
        enemy.physicsBody?.contactTestBitMask = categoryPlayer | categoryPlayerBullet
        enemy.physicsBody?.collisionBitMask = 0
        addChild(enemy)

        let move = SKAction.moveTo(y: -enemy.size.height, duration: 5.0)
        let remove = SKAction.removeFromParent()
        enemy.run(SKAction.sequence([move, remove]))

        // Enemy bullets – elke 3 sec per enemy
        let wait = SKAction.wait(forDuration: enemyFireInterval)
        let shoot = SKAction.run { [weak self, weak enemy] in
            guard let self = self, let enemy = enemy, enemy.parent != nil else { return }
            self.fireEnemyBullet(from: enemy)
        }
        let shootLoop = SKAction.repeatForever(SKAction.sequence([wait, shoot]))
        enemy.run(shootLoop, withKey: "enemyShoot")
    }

    private func addExplosion(at position: CGPoint) {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 80
        emitter.numParticlesToEmit = 40
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = .pi * 2
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.2
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -2.0
        emitter.particleColor = .orange
        emitter.particleColorBlendFactor = 1.0
        emitter.position = position
        emitter.zPosition = 50
        addChild(emitter)
        let wait = SKAction.wait(forDuration: 0.5)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let maskA = bodyA.categoryBitMask
        let maskB = bodyB.categoryBitMask

        // Player bullet vs Enemy – enemy explode, score +10
        if (maskA == categoryPlayerBullet && maskB == categoryEnemy) || (maskA == categoryEnemy && maskB == categoryPlayerBullet) {
            let bullet = maskA == categoryPlayerBullet ? bodyA.node : bodyB.node
            let enemy = maskA == categoryEnemy ? bodyA.node : bodyB.node
            let hitPos = enemy?.position ?? bullet?.position ?? .zero
            bullet?.removeFromParent()
            enemy?.removeFromParent()
            addExplosion(at: hitPos)
            addScore(10)
        }

        // Enemy bullet vs Player – game over
        if (maskA == categoryEnemyBullet && maskB == categoryPlayer) || (maskA == categoryPlayer && maskB == categoryEnemyBullet) {
            let bullet = maskA == categoryEnemyBullet ? bodyA.node : bodyB.node
            bullet?.removeFromParent()
            triggerGameOver()
        }

        // Player vs Enemy (ram) – game over
        if (maskA == categoryPlayer && maskB == categoryEnemy) || (maskA == categoryEnemy && maskB == categoryPlayer) {
            let enemy = maskA == categoryEnemy ? bodyA.node : bodyB.node
            enemy?.removeFromParent()
            triggerGameOver()
        }
    }

    private func addScore(_ points: Int) {
        score += points
        scoreLabel.text = "Score: \(score)"
    }

    private func triggerGameOver() {
        gameOver = true
        physicsWorld.contactDelegate = nil
        player.removeFromParent()

        let overlay = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 199
        addChild(overlay)

        let label = SKLabelNode(fontNamed: "Avenir-Bold")
        label.fontSize = 64
        label.fontColor = .white
        label.text = "GAME OVER"
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 200
        addChild(label)

        let sub = SKLabelNode(fontNamed: "Avenir")
        sub.fontSize = 32
        sub.fontColor = .gray
        sub.text = "Score: \(score)"
        sub.position = CGPoint(x: size.width / 2, y: size.height / 2 - 70)
        sub.zPosition = 200
        addChild(sub)
    }
}

// ✅ SHOOTING KLAAR - commit/push nu, dan prompt 3 voor game loop
