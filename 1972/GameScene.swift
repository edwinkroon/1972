//
//  GameScene.swift
//  1972
//
//  1942/1943 vertical shooter. Lives, waves, highscore, powerups, scroll bg.
//

import SpriteKit
import GameplayKit
import UIKit

// Physics categories
private let categoryPlayer:       UInt32 = 0x1 << 0
private let categoryEnemy:        UInt32 = 0x1 << 1
private let categoryPlayerBullet: UInt32 = 0x1 << 2
private let categoryEnemyBullet:  UInt32 = 0x1 << 3
private let categoryPowerup:      UInt32 = 0x1 << 4

private let highscoreKey = "highscore1972"
private let maxPlayerBullets = 5
private let playerBulletSize = CGSize(width: 14, height: 24)
private let playerFireInterval: TimeInterval = 0.12
private let enemyBulletSize = CGSize(width: 8, height: 16)
private let enemyFireInterval: TimeInterval = 3.0
private let powerupDropChance: Float = 0.15
private let tripleShotDuration: TimeInterval = 10.0
private let invincibilityDuration: TimeInterval = 1.5
private let waveDuration: TimeInterval = 30.0

class GameScene: SKScene, SKPhysicsContactDelegate {

    private var player: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0
    private var lastSpawnTime: TimeInterval = 0
    private var spawnInterval: TimeInterval = 2.0
    private var touchLocationX: CGFloat?
    private var gameOver = false
    private var lastPlayerFireTime: TimeInterval = 0
    private var gameStartTime: TimeInterval = 0
    private var waveIndex: Int = 0
    private var lives: Int = 3
    private var heartNodes: [SKNode] = []
    private var invincibleUntil: TimeInterval = 0
    private var tripleShotUntil: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var backgroundNode: SKNode!
    private var cloudNode: SKNode!
    private var gradientSprite1: SKSpriteNode!
    private var gradientSprite2: SKSpriteNode!

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        lastUpdateTime = 0
        gameStartTime = 0
        waveIndex = 0
        spawnInterval = 2.0

        // Scrollende blauwe gradient background
        setupScrollingGradient()

        // Wolken parallax
        setupClouds()

        // Player – sprite uit Assets (playerShip)
        player = SKSpriteNode(imageNamed: "playerShip")
        player.position = CGPoint(x: size.width / 2, y: 80)
        player.name = "player"
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = false
        player.physicsBody?.categoryBitMask = categoryPlayer
        player.physicsBody?.contactTestBitMask = categoryEnemy | categoryEnemyBullet | categoryPowerup
        player.physicsBody?.collisionBitMask = 0
        player.zPosition = 20
        addChild(player)

        // Lives – 3 hart-icons linksboven
        lives = 3
        heartNodes.removeAll()
        let heartSize: CGFloat = 32
        let heartSpacing: CGFloat = 40
        let heartY = size.height - 60
        for i in 0..<3 {
            let heart = makeHeartNode(size: heartSize)
            heart.position = CGPoint(x: 60 + CGFloat(i) * heartSpacing, y: heartY)
            heart.zPosition = 100
            heart.name = "heart\(i)"
            addChild(heart)
            heartNodes.append(heart)
        }

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

    private func makeHeartNode(size: CGFloat) -> SKNode {
        let container = SKNode()
        let r = size / 2
        let circle = SKShapeNode(circleOfRadius: r)
        circle.fillColor = .red
        circle.strokeColor = .clear
        container.addChild(circle)
        return container
    }

    private func setupScrollingGradient() {
        let w = size.width
        let h = size.height * 2
        let texture = makeGradientTexture(width: w, height: h)
        gradientSprite1 = SKSpriteNode(texture: texture, size: CGSize(width: w, height: h))
        gradientSprite2 = SKSpriteNode(texture: texture, size: CGSize(width: w, height: h))
        gradientSprite1.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gradientSprite2.position = CGPoint(x: size.width / 2, y: size.height / 2 + h)
        gradientSprite1.zPosition = -10
        gradientSprite2.zPosition = -10
        addChild(gradientSprite1)
        addChild(gradientSprite2)

        let moveUp = SKAction.moveBy(x: 0, y: -h, duration: 8)
        let reset = SKAction.moveBy(x: 0, y: h, duration: 0)
        let loop = SKAction.repeatForever(SKAction.sequence([moveUp, reset]))
        gradientSprite1.run(loop)
        gradientSprite2.run(SKAction.sequence([SKAction.wait(forDuration: 4), loop]))
    }

    private func makeGradientTexture(width: CGFloat, height: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            let colors = [
                UIColor(red: 0.1, green: 0.25, blue: 0.5, alpha: 1).cgColor,
                UIColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1).cgColor,
                UIColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1).cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: width/2, y: 0), end: CGPoint(x: width/2, y: height), options: [])
        }
        return SKTexture(image: image)
    }

    private func setupClouds() {
        cloudNode = SKNode()
        cloudNode.zPosition = -5
        addChild(cloudNode)
        let cloudCount = 12
        for _ in 0..<cloudCount {
            let cloud = makeCloud()
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height * 1.2)
            )
            cloudNode.addChild(cloud)
        }
    }

    private func makeCloud() -> SKNode {
        let group = SKNode()
        let scale = CGFloat.random(in: 0.4...1.2)
        for _ in 0..<4 {
            let el = SKShapeNode(ellipseOf: CGSize(width: 60 * scale, height: 30 * scale))
            el.fillColor = SKColor(white: 1, alpha: 0.5)
            el.strokeColor = .clear
            el.position = CGPoint(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -15...15))
            group.addChild(el)
        }
        group.name = "cloud"
        group.setScale(scale)
        return group
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if gameOver {
            let node = atPoint(location)
            if node.name == "restartButton" || node.parent?.name == "restartButton" {
                let newScene = GameScene(size: size)
                newScene.scaleMode = scaleMode
                view?.presentScene(newScene, transition: .crossFade(withDuration: 0.5))
            }
            return
        }
        touchLocationX = location.x
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
        if lastUpdateTime == 0 { lastUpdateTime = currentTime; gameStartTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        if gameOver { return }

        // Parallax clouds
        cloudNode.position.y -= dt * 25
        for child in cloudNode.children {
            if let cloud = child as? SKNode, cloud.name == "cloud" {
                cloud.position.y -= dt * 15 * CGFloat(cloud.xScale)
            }
        }
        if cloudNode.position.y < -size.height { cloudNode.position.y += size.height }

        // Move player
        if let x = touchLocationX {
            let half = player.size.width / 2
            let clampedX = max(half, min(size.width - half, x))
            player.position.x = clampedX
        }

        // Player fire – single or triple shot
        if touchLocationX != nil, currentTime - lastPlayerFireTime >= playerFireInterval {
            let count = children.filter { $0.name == "playerBullet" }.count
            let limit = currentTime < tripleShotUntil ? maxPlayerBullets + 10 : maxPlayerBullets
            if count < limit {
                lastPlayerFireTime = currentTime
                if currentTime < tripleShotUntil {
                    fireTripleShot()
                } else {
                    firePlayerBullet()
                }
            }
        }

        // Enemy waves – elke 30 sec snellere spawn
        let elapsed = currentTime - gameStartTime
        let nextWaveTime = waveDuration * TimeInterval(waveIndex + 1)
        if elapsed >= nextWaveTime {
            waveIndex += 1
            spawnInterval = max(0.6, spawnInterval * 0.82)
        }

        // Spawn enemies (possibly 2 in later waves)
        if currentTime - lastSpawnTime > spawnInterval {
            lastSpawnTime = currentTime
            spawnEnemy()
            if waveIndex >= 1 && Bool.random() { spawnEnemy() }
            if waveIndex >= 2 && Bool.random() { spawnEnemy() }
        }
    }

    private func firePlayerBullet() {
        addBullet(at: player.position, offsetX: 0)
    }

    private func fireTripleShot() {
        let dx: CGFloat = 25
        addBullet(at: player.position, offsetX: -dx)
        addBullet(at: player.position, offsetX: 0)
        addBullet(at: player.position, offsetX: dx)
    }

    private func addBullet(at basePos: CGPoint, offsetX: CGFloat) {
        let bullet = SKSpriteNode(color: .white, size: playerBulletSize)
        bullet.position = CGPoint(
            x: basePos.x + offsetX,
            y: basePos.y + player.size.height / 2 + playerBulletSize.height / 2
        )
        bullet.name = "playerBullet"
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.isDynamic = false
        bullet.physicsBody?.usesPreciseCollisionDetection = true  // voorkomt tunnelen door vijand
        bullet.physicsBody?.categoryBitMask = categoryPlayerBullet
        bullet.physicsBody?.contactTestBitMask = categoryEnemy
        bullet.physicsBody?.collisionBitMask = 0
        bullet.zPosition = 15
        addChild(bullet)
        let move = SKAction.moveTo(y: size.height + bullet.size.height, duration: 0.6)
        bullet.run(SKAction.sequence([move, SKAction.removeFromParent()]))
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
        bullet.zPosition = 15
        addChild(bullet)
        let move = SKAction.moveTo(y: -bullet.size.height, duration: 2.0)
        bullet.run(SKAction.sequence([move, SKAction.removeFromParent()]))
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
        enemy.zPosition = 15
        addChild(enemy)

        let duration = max(3.0, 5.0 - TimeInterval(waveIndex) * 0.3)
        let move = SKAction.moveTo(y: -enemy.size.height, duration: duration)
        enemy.run(SKAction.sequence([move, SKAction.removeFromParent()]))

        let wait = SKAction.wait(forDuration: enemyFireInterval)
        let shoot = SKAction.run { [weak self, weak enemy] in
            guard let self = self, let enemy = enemy, enemy.parent != nil else { return }
            self.fireEnemyBullet(from: enemy)
        }
        enemy.run(SKAction.repeatForever(SKAction.sequence([wait, shoot])), withKey: "enemyShoot")
    }

    private func trySpawnPowerup(at position: CGPoint) {
        if Float.random(in: 0...1) > powerupDropChance { return }
        let pw = SKSpriteNode(color: .cyan, size: CGSize(width: 24, height: 24))
        pw.position = position
        pw.name = "powerup"
        pw.physicsBody = SKPhysicsBody(rectangleOf: pw.size)
        pw.physicsBody?.isDynamic = false
        pw.physicsBody?.categoryBitMask = categoryPowerup
        pw.physicsBody?.contactTestBitMask = categoryPlayer
        pw.physicsBody?.collisionBitMask = 0
        pw.zPosition = 18
        addChild(pw)
        let move = SKAction.moveTo(y: -pw.size.height, duration: 6)
        pw.run(SKAction.sequence([move, SKAction.removeFromParent()]))
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
        emitter.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.removeFromParent()]))
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let maskA = bodyA.categoryBitMask
        let maskB = bodyB.categoryBitMask

        // Player bullet vs Enemy
        if (maskA == categoryPlayerBullet && maskB == categoryEnemy) || (maskA == categoryEnemy && maskB == categoryPlayerBullet) {
            let bullet = maskA == categoryPlayerBullet ? bodyA.node : bodyB.node
            let enemy = maskA == categoryEnemy ? bodyA.node : bodyB.node
            let hitPos = enemy?.position ?? bullet?.position ?? .zero
            bullet?.removeFromParent()
            enemy?.removeFromParent()
            addExplosion(at: hitPos)
            addScore(10)
            trySpawnPowerup(at: hitPos)
        }

        // Powerup vs Player
        if (maskA == categoryPowerup && maskB == categoryPlayer) || (maskA == categoryPlayer && maskB == categoryPowerup) {
            let pw = maskA == categoryPowerup ? bodyA.node : bodyB.node
            pw?.removeFromParent()
            tripleShotUntil = lastUpdateTime + tripleShotDuration
        }

        // Enemy bullet vs Player – lose life
        if (maskA == categoryEnemyBullet && maskB == categoryPlayer) || (maskA == categoryPlayer && maskB == categoryEnemyBullet) {
            let bullet = maskA == categoryEnemyBullet ? bodyA.node : bodyB.node
            bullet?.removeFromParent()
            if lastUpdateTime >= invincibleUntil { playerHit() }
        }

        // Player vs Enemy (ram)
        if (maskA == categoryPlayer && maskB == categoryEnemy) || (maskA == categoryEnemy && maskB == categoryPlayer) {
            let enemy = maskA == categoryEnemy ? bodyA.node : bodyB.node
            enemy?.removeFromParent()
            if lastUpdateTime >= invincibleUntil { playerHit() }
        }
    }

    private func playerHit() {
        invincibleUntil = lastUpdateTime + invincibilityDuration
        lives -= 1
        if lives >= 0 && lives < heartNodes.count {
            heartNodes[lives].run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
            heartNodes.remove(at: lives)
        }
        if lives <= 0 {
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

        // Highscore
        let defaults = UserDefaults.standard
        let prevHigh = defaults.integer(forKey: highscoreKey)
        if score > prevHigh {
            defaults.set(score, forKey: highscoreKey)
        }
        let highscore = max(score, prevHigh)

        let overlay = SKSpriteNode(color: SKColor(white: 0, alpha: 0.65), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 199
        overlay.name = "overlay"
        addChild(overlay)

        let label = SKLabelNode(fontNamed: "Avenir-Bold")
        label.fontSize = 64
        label.fontColor = .white
        label.text = "GAME OVER"
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80)
        label.zPosition = 200
        addChild(label)

        let sub = SKLabelNode(fontNamed: "Avenir")
        sub.fontSize = 32
        sub.fontColor = .gray
        sub.text = "Score: \(score)"
        sub.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        sub.zPosition = 200
        addChild(sub)

        let highLabel = SKLabelNode(fontNamed: "Avenir-Bold")
        highLabel.fontSize = 28
        highLabel.fontColor = .yellow
        highLabel.text = "High Score: \(highscore)"
        highLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        highLabel.zPosition = 200
        addChild(highLabel)

        let restartBg = SKSpriteNode(color: SKColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1), size: CGSize(width: 220, height: 56))
        restartBg.position = CGPoint(x: size.width / 2, y: size.height / 2 - 130)
        restartBg.zPosition = 200
        restartBg.name = "restartButton"
        addChild(restartBg)

        let restartLabel = SKLabelNode(fontNamed: "Avenir-Bold")
        restartLabel.fontSize = 32
        restartLabel.fontColor = .white
        restartLabel.text = "RESTART"
        restartLabel.verticalAlignmentMode = .center
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 130)
        restartLabel.zPosition = 201
        restartLabel.name = "restartButton"
        addChild(restartLabel)
    }
}

// 🎮 VOLLEDIGE GAME KLAAR - test in Xcode!
