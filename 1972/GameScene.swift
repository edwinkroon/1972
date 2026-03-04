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
private let categoryPlayerRocket: UInt32 = 0x1 << 5

private let highscoreKey = "highscore1972"
private let maxPlayerBullets = 25  // genoeg dat vuren niet stopt zolang je het scherm vasthoudt
private let playerBulletSize = CGSize(width: 5, height: 7.5)   // 25% groter dan 4x6
private let playerFireInterval: TimeInterval = 0.12
private let enemyBulletSize = CGSize(width: 2.5, height: 5)   // 25% groter dan 2x4
private let enemyFireInterval: TimeInterval = 1.0
private let powerupDropChance: Float = 0.15
private let tripleShotDuration: TimeInterval = 10.0
private let spreadShotDuration: TimeInterval = 10.0
private let spreadShotAngleDegrees: CGFloat = 20
private let laserDuration: TimeInterval = 8.0
private let wingmanDuration: TimeInterval = 12.0
private let wingmanOffset: CGFloat = 72  // afstand links/rechts van speler
private let rocketDuration: TimeInterval = 12.0
private let rocketFireInterval: TimeInterval = 0.6
private let maxRockets = 3
/// Zet op false om raketten alleen recht omhoog te laten vliegen (geen heat-seeking) – handig om te testen
private let rocketHomingEnabled = true
/// Maximale draaisnelheid in radialen per seconde – raket is zwaar, kan niet snel draaien
private let rocketMaxTurnRate: CGFloat = 1.0
private let bulletScore = 10
private let rocketScore = 25
private let invincibilityDuration: TimeInterval = 1.5
private let waveDuration: TimeInterval = 30.0
private let formationSpawnInterval: TimeInterval = 14.0   // formatie alienplanes elke ~14 sec
private let formationSpacing: CGFloat = 72                // afstand tussen vliegtuigen in formatie
private let enemy1DebrisColor = SKColor(red: 0.35, green: 0.4, blue: 0.45, alpha: 1)   // grijs
private let alienplaneDebrisColor = SKColor(red: 0.2, green: 0.5, blue: 0.25, alpha: 1)  // groen

class GameScene: SKScene, SKPhysicsContactDelegate {

    // Snelheden en tuning (instance properties voor gebruik in update/touches/closures)
    private var rocketSpeed: CGFloat = 400.0  // 50% langzamer (was 800)
    private var bulletSpeed: CGFloat = 600.0      // pixels/sec omhoog (bullet move duration afgeleid)
    private var enemyBulletSpeed: CGFloat = 250.0

    private var player: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var score: Int = 0
    private var lastSpawnTime: TimeInterval = 0
    private var spawnInterval: TimeInterval = 2.0
    private var touchLocation: CGPoint?   // x en y voor horizontaal + verticaal bewegen
    private var gameOver = false
    private var lastPlayerFireTime: TimeInterval = 0
    private var gameStartTime: TimeInterval = 0
    private var waveIndex: Int = 0
    private var lives: Int = 3
    private var playerHealth: CGFloat = 100   // per leven; kogel -20, bij 0 verlies je een leven
    private var playerHealthBar: SKSpriteNode?  // groene balk onder het vliegtuig
    private var heartNodes: [SKNode] = []
    private var invincibleUntil: TimeInterval = 0
    private var tripleShotUntil: TimeInterval = 0
    private var spreadShotUntil: TimeInterval = 0
    private var laserUntil: TimeInterval = 0
    private var laserBeamNode: SKSpriteNode?
    private var wingmanUntil: TimeInterval = 0
    private var leftWingmanNode: SKSpriteNode?
    private var rightWingmanNode: SKSpriteNode?
    private var rocketUntil: TimeInterval = 0
    private var lastRocketFireTime: TimeInterval = 0
    private var lastFormationSpawnTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var backgroundNode: SKNode!
    private var spaceParallaxNode: SKNode!   // planeten (snellere laag)
    private var starParallaxNode: SKNode!    // ster-asset (langzamere laag)
    private let planetParallaxSpeed: CGFloat = 18.0
    private let starParallaxSpeed: CGFloat = 8.0
    private var splashNode: SKNode?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.08, blue: 0.18, alpha: 1)

        // Splash direct tonen zodat je ziet dat de scene start (ook bij zwart scherm)
        showSplash()

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        lastUpdateTime = 0
        gameStartTime = 0
        waveIndex = 0
        spawnInterval = 2.0

        // Achtergrond = effen donker space blauw (backgroundColor)

        // Sterren en planeten met parallax
        setupSpaceParallax()

        // Player – sprite uit Assets (playerShip)
        player = SKSpriteNode(imageNamed: "playerShip")
        player.position = CGPoint(x: size.width / 2, y: 220)  // default wat hoger van de onderkant
        player.name = "player"
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = false
        player.physicsBody?.categoryBitMask = categoryPlayer
        player.physicsBody?.contactTestBitMask = categoryEnemy | categoryEnemyBullet | categoryPowerup
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.usesPreciseCollisionDetection = true
        player.zPosition = 20
        addChild(player)

        // Healthbar onder het vliegtuig (even breed als het vliegtuig)
        let barW = player.size.width
        let barH: CGFloat = 3
        let barY = -player.size.height / 2 - barH / 2 - 4
        let bg = SKSpriteNode(color: SKColor(white: 0.2, alpha: 0.9), size: CGSize(width: barW, height: barH))
        bg.position = CGPoint(x: 0, y: barY)
        bg.zPosition = -1
        player.addChild(bg)
        let fill = SKSpriteNode(color: SKColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1), size: CGSize(width: barW, height: barH))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -barW / 2, y: barY)
        fill.zPosition = 0
        fill.xScale = 1.0
        player.addChild(fill)
        playerHealthBar = fill

        // Bovenbalk: levens links, score rechts
        let barHeight: CGFloat = 44
        let topBar = SKNode()
        topBar.position = CGPoint(x: size.width / 2, y: size.height - barHeight / 2)
        topBar.zPosition = 100
        let barBg = SKSpriteNode(color: SKColor(white: 0.1, alpha: 0.75), size: CGSize(width: size.width + 2, height: barHeight + 2))
        barBg.position = .zero
        barBg.zPosition = -1
        topBar.addChild(barBg)
        addChild(topBar)

        // Levens – hartjes links uitgelijnd
        lives = 3
        playerHealth = 100
        heartNodes.removeAll()
        let heartSize: CGFloat = 20
        let heartSpacing: CGFloat = 10
        let edgeMargin: CGFloat = 14
        for i in 0..<3 {
            let heart = makeHeartNode(size: heartSize)
            heart.position = CGPoint(x: -size.width / 2 + edgeMargin + heartSize / 2 + CGFloat(i) * (heartSize + heartSpacing), y: 0)
            heart.zPosition = 1
            heart.name = "heart\(i)"
            topBar.addChild(heart)
            heartNodes.append(heart)
        }

        // Score – rechts uitgelijnd
        scoreLabel = SKLabelNode(fontNamed: "Avenir-Bold")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2 - edgeMargin, y: 0)
        scoreLabel.zPosition = 1
        scoreLabel.text = "Score: 0"
        topBar.addChild(scoreLabel)
    }

    private func showSplash() {
        let w = max(size.width, 320)
        let h = max(size.height, 480)
        let splash = SKSpriteNode(color: SKColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1), size: CGSize(width: w, height: h))
        splash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        splash.zPosition = 1000
        splash.name = "splash"

        let title = SKLabelNode(fontNamed: "Avenir-Bold")
        title.text = "1972"
        title.fontSize = 72
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 20)
        title.zPosition = 1001
        splash.addChild(title)

        let sub = SKLabelNode(fontNamed: "Avenir")
        sub.text = "Tap to start"
        sub.fontSize = 28
        sub.fontColor = .white
        sub.position = CGPoint(x: 0, y: -50)
        sub.zPosition = 1001
        splash.addChild(sub)

        addChild(splash)
        splashNode = splash

        let wait = SKAction.wait(forDuration: 2.5)
        let fade = SKAction.fadeOut(withDuration: 0.5)
        splash.run(SKAction.sequence([wait, fade, SKAction.removeFromParent()])) { [weak self] in
            self?.splashNode = nil
        }
    }

    private func makeHeartNode(size: CGFloat) -> SKNode {
        let ship = SKSpriteNode(imageNamed: "playerShip")
        let scale = size / max(ship.size.width, ship.size.height)
        ship.setScale(scale)
        ship.zRotation = -15 * .pi / 180  // 15° naar rechts
        return ship
    }

    /// Parallax-achtergrond met ster- en planeet-assets; sterren scrollen langzamer dan planeten voor diepte.
    private func setupSpaceParallax() {
        let w = size.width
        let h = size.height * 2.2

        // Ster-laag (langzame scroll)
        starParallaxNode = SKNode()
        starParallaxNode.zPosition = -8
        let starCount = 5
        for _ in 0..<starCount {
            let star = SKSpriteNode(imageNamed: "star1")
            star.name = "spaceStar"
            let scale = CGFloat.random(in: 0.15...0.45)
            star.setScale(scale)
            star.position = CGPoint(x: CGFloat.random(in: 0...w), y: CGFloat.random(in: 0...h))
            star.alpha = CGFloat.random(in: 0.5...1.0)
            starParallaxNode.addChild(star)
        }
        starParallaxNode.position = .zero
        addChild(starParallaxNode)

        // Planeet-laag vóór sterren (snellere scroll = parallax)
        spaceParallaxNode = SKNode()
        spaceParallaxNode.zPosition = -7
        let planetNames = ["planet1", "planet2", "planet3", "planet4", "planet5", "planet6", "planet7"]
        let planetCount = 8
        for i in 0..<planetCount {
            let name = planetNames[i % planetNames.count]
            let planet = SKSpriteNode(imageNamed: name)
            planet.name = "spacePlanet"
            let scale = CGFloat.random(in: 0.08...0.22)
            planet.setScale(scale)
            planet.position = CGPoint(x: CGFloat.random(in: 0...w), y: CGFloat.random(in: 0...h))
            planet.alpha = CGFloat.random(in: 0.6...1.0)
            spaceParallaxNode.addChild(planet)
        }
        spaceParallaxNode.position = .zero
        addChild(spaceParallaxNode)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let splash = splashNode {
            splash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
            splashNode = nil
            touchLocation = location
            return
        }

        if gameOver {
            let node = atPoint(location)
            if node.name == "restartButton" || node.parent?.name == "restartButton" {
                let newScene = GameScene(size: size)
                newScene.scaleMode = scaleMode
                view?.presentScene(newScene, transition: .crossFade(withDuration: 0.5))
            }
            return
        }
        touchLocation = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !gameOver else { return }
        touchLocation = touches.first?.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchLocation = nil
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime; gameStartTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        if gameOver { return }

        // Parallax sterren (langzaam) en planeten (sneller) voor diepte; naadloze wrap op content-hoogte
        let spaceContentH = size.height * 2.2
        if let stars = starParallaxNode {
            stars.position.y -= starParallaxSpeed * CGFloat(dt)
            if stars.position.y < -spaceContentH { stars.position.y += spaceContentH }
        }
        if let planets = spaceParallaxNode {
            planets.position.y -= planetParallaxSpeed * CGFloat(dt)
            if planets.position.y < -spaceContentH { planets.position.y += spaceContentH }
        }

        // Move player (horizontaal + verticaal)
        if let loc = touchLocation {
            let halfW = player.size.width / 2
            let halfH = player.size.height / 2
            let minY: CGFloat = 80
            let maxY = size.height - 60  // onder de bovenbalk
            player.position.x = max(halfW, min(size.width - halfW, loc.x))
            player.position.y = max(minY + halfH, min(maxY - halfH, loc.y))
        }

        // Laser: beam bijhouden en vijanden in straal raken
        if currentTime < laserUntil {
            updateLaserBeam(dt: dt)
        } else if laserBeamNode != nil {
            laserBeamNode?.removeFromParent()
            laserBeamNode = nil
        }

        // Wingmen: opruimen als powerup is afgelopen
        if currentTime >= wingmanUntil {
            leftWingmanNode?.removeFromParent()
            rightWingmanNode?.removeFromParent()
            leftWingmanNode = nil
            rightWingmanNode = nil
        }

        // Player fire – single, triple, spread (niet tijdens laser)
        if touchLocation != nil, currentTime >= laserUntil, currentTime - lastPlayerFireTime >= playerFireInterval {
            let count = children.filter { $0.name == "playerBullet" }.count
            var limit = currentTime < tripleShotUntil ? maxPlayerBullets + 20 : maxPlayerBullets
            if currentTime < wingmanUntil { limit += 20 }
            if count < limit {
                lastPlayerFireTime = currentTime
                if currentTime < tripleShotUntil {
                    fireTripleShot()
                } else if currentTime < spreadShotUntil {
                    fireSpreadShot()
                } else {
                    firePlayerBullet()
                }
                if currentTime < wingmanUntil { fireWingmanBullets() }
            }
        }

        // Heat-seeking rockets (aparte powerup)
        if touchLocation != nil, currentTime < rocketUntil, currentTime - lastRocketFireTime >= rocketFireInterval {
            let rocketCount = children.filter { $0.name == "playerRocket" }.count
            if rocketCount < maxRockets {
                lastRocketFireTime = currentTime
                fireRocket()
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

        // Formaties alienplanes (vanaf wave 1)
        if waveIndex >= 1 && currentTime - lastFormationSpawnTime > formationSpawnInterval {
            lastFormationSpawnTime = currentTime
            spawnEnemyFormation()
        }

        // Kogels met richting (spread shot): beweeg in hun hoek
        let spreadAngleRad = spreadShotAngleDegrees * .pi / 180
        enumerateChildNodes(withName: "playerBullet") { bullet, _ in
            guard let angle = bullet.userData?["angle"] as? CGFloat else { return }
            let dx = sin(angle) * self.bulletSpeed * CGFloat(dt)
            let dy = cos(angle) * self.bulletSpeed * CGFloat(dt)
            bullet.position.x += dx
            bullet.position.y += dy
            if bullet.position.y > self.size.height + 50 || bullet.position.y < -50 || bullet.position.x < -50 || bullet.position.x > self.size.width + 50 {
                bullet.removeFromParent()
            }
        }

        // Handmatige hit: kogel vs vijand – kogel stopt bij eerste treffer (gaat niet door)
        var hits: [(bullet: SKNode, enemy: SKNode)] = []
        enumerateChildNodes(withName: "playerBullet") { bullet, _ in
            var bulletHit = false
            self.enumerateChildNodes(withName: "enemy") { enemy, _ in
                if !bulletHit && bullet.frame.intersects(enemy.frame) {
                    hits.append((bullet, enemy))
                    bulletHit = true  // één kogel = één treffer, daarna stopt de kogel
                }
            }
        }
        for (bullet, enemy) in hits {
            let pos = enemy.position
            let color = debrisColor(for: enemy)
            bullet.removeAllActions()
            bullet.removeFromParent()  // kogel verdwijnt direct, vliegt niet door
            enemy.removeFromParent()
            addEnemyDebris(at: pos, color: color)
            addScore(bulletScore)
            trySpawnPowerup(at: pos)
        }

        // Raketten: zwaar gedrag – stuwkracht alleen achterin, traag draaien, alleen vijanden op scherm
        let rocketStraightDuration: TimeInterval = 0.1
        let margin: CGFloat = 40
        let onScreen = { (p: CGPoint) in
            p.x >= -margin && p.x <= self.size.width + margin && p.y >= -margin && p.y <= self.size.height + margin
        }
        enumerateChildNodes(withName: "playerRocket") { rocket, _ in
            guard let rocket = rocket as? SKSpriteNode else { return }
            let spawnTime = (rocket.userData?["spawnTime"] as? TimeInterval) ?? 0
            var heading = CGFloat((rocket.userData?["heading"] as? Double) ?? 0)
            let flyingStraight = (currentTime - spawnTime) < rocketStraightDuration

            var targetNode: SKNode?
            if rocketHomingEnabled && !flyingStraight, let locked = rocket.userData?["target"] as? SKNode, locked.parent != nil, onScreen(locked.position) {
                targetNode = locked
            }
            if rocketHomingEnabled && targetNode == nil && !flyingStraight {
                var nearest: (node: SKNode, dist: CGFloat)?
                self.enumerateChildNodes(withName: "enemy") { enemy, _ in
                    guard onScreen(enemy.position) else { return }
                    let dx = enemy.position.x - rocket.position.x
                    let dy = enemy.position.y - rocket.position.y
                    let d = dx * dx + dy * dy
                    if nearest == nil || d < nearest!.dist { nearest = (enemy, d) }
                }
                targetNode = nearest?.node
                if targetNode != nil {
                    var ud = rocket.userData ?? [:]
                    ud["target"] = targetNode!
                    rocket.userData = ud
                }
            }
            if targetNode == nil { rocket.userData?["target"] = nil }

            // heading 0 = omhoog (asset wijst al omhoog bij zRotation 0)
            let desiredAngle: CGFloat
            if flyingStraight || targetNode == nil {
                desiredAngle = 0
            } else if let target = targetNode {
                let dx = target.position.x - rocket.position.x
                let dy = target.position.y - rocket.position.y
                desiredAngle = atan2(dx, dy)  // hoek t.o.v. positieve y-as (omhoog)
            } else {
                desiredAngle = heading
            }

            var diff = desiredAngle - heading
            while diff > .pi { diff -= 2 * .pi }; while diff < -.pi { diff += 2 * .pi }
            let maxTurn = rocketMaxTurnRate * CGFloat(dt)
            heading += max(-maxTurn, min(maxTurn, diff))
            var ud = rocket.userData ?? [:]
            ud["heading"] = Double(heading)
            if targetNode == nil { ud["target"] = nil }
            rocket.userData = ud
            // SpriteKit: lokale +y wijst naar (-sin(zRotation), cos(zRotation)); wij willen (sin(heading), cos(heading)) → zRotation = -heading
            rocket.zRotation = -heading

            let moveX = sin(heading) * self.rocketSpeed * CGFloat(dt)
            let moveY = cos(heading) * self.rocketSpeed * CGFloat(dt)
            rocket.position.x += moveX
            rocket.position.y += moveY

            if rocket.position.y > self.size.height + 60 || rocket.position.y < -60 {
                rocket.removeFromParent()
            }
        }

        // Rocket vs enemy hit (meer damage = meer punten)
        var rocketHits: [(rocket: SKNode, enemy: SKNode)] = []
        enumerateChildNodes(withName: "playerRocket") { rocket, _ in
            var hit = false
            self.enumerateChildNodes(withName: "enemy") { enemy, _ in
                if !hit && rocket.frame.intersects(enemy.frame) {
                    rocketHits.append((rocket, enemy))
                    hit = true
                }
            }
        }
        for (rocket, enemy) in rocketHits {
            let pos = enemy.position
            let color = debrisColor(for: enemy)
            rocket.removeFromParent()
            enemy.removeFromParent()
            addEnemyDebris(at: pos, color: color)
            addScore(rocketScore)
            trySpawnPowerup(at: pos)
        }

        // Handmatige powerup-pickup (physics contact mist vaak)
        enumerateChildNodes(withName: "powerupTriple") { pw, _ in
            if self.player.parent != nil && pw.frame.intersects(self.player.frame) {
                pw.removeFromParent()
                self.tripleShotUntil = self.lastUpdateTime + tripleShotDuration
            }
        }
        enumerateChildNodes(withName: "powerupRocket") { pw, _ in
            if self.player.parent != nil && pw.frame.intersects(self.player.frame) {
                pw.removeFromParent()
                self.rocketUntil = self.lastUpdateTime + rocketDuration
            }
        }
        enumerateChildNodes(withName: "powerupSpread") { pw, _ in
            if self.player.parent != nil && pw.frame.intersects(self.player.frame) {
                pw.removeFromParent()
                self.spreadShotUntil = self.lastUpdateTime + spreadShotDuration
            }
        }
        enumerateChildNodes(withName: "powerupLaser") { pw, _ in
            if self.player.parent != nil && pw.frame.intersects(self.player.frame) {
                pw.removeFromParent()
                self.activateLaser()
            }
        }
        enumerateChildNodes(withName: "powerupWingman") { pw, _ in
            if self.player.parent != nil && pw.frame.intersects(self.player.frame) {
                pw.removeFromParent()
                self.activateWingmen()
            }
        }

        // Handmatige hit: vijandkogel / vliegtuig vs speler (fallback als physics contact mist)
        guard player.parent != nil, !gameOver else { return }
        enumerateChildNodes(withName: "enemyBullet") { bullet, _ in
            if bullet.frame.intersects(self.player.frame), self.lastUpdateTime >= self.invincibleUntil {
                bullet.removeFromParent()
                self.playerHitByBullet()
            }
        }
        enumerateChildNodes(withName: "enemy") { enemy, _ in
            if enemy.frame.intersects(self.player.frame) {
                let pos = enemy.position
                let color = self.debrisColor(for: enemy)
                enemy.removeFromParent()
                self.addEnemyDebris(at: pos, color: color)
                self.triggerGameOver()
                return  // stop meteen na game over
            }
        }
    }

    private func firePlayerBullet() {
        addBullet(at: player.position, offsetX: 0)
    }

    private func fireTripleShot() {
        let dx: CGFloat = 38
        addBullet(at: player.position, offsetX: -dx, imageName: "bullet2")   // links
        addBullet(at: player.position, offsetX: 0, imageName: "bullet1")    // midden (default)
        addBullet(at: player.position, offsetX: dx, imageName: "bullet3")    // rechts
    }

    private func fireSpreadShot() {
        let angleRad = spreadShotAngleDegrees * .pi / 180
        addBullet(at: player.position, offsetX: 0, imageName: "bullet1", angle: -angleRad)   // 20° links
        addBullet(at: player.position, offsetX: 0, imageName: "bullet1", angle: 0)            // recht vooruit
        addBullet(at: player.position, offsetX: 0, imageName: "bullet1", angle: angleRad)    // 20° rechts
    }

    private func fireRocket() {
        let rocket = SKSpriteNode(imageNamed: "rocket")
        let scale: CGFloat = 0.25  // 50% kleiner (was 0.5)
        rocket.setScale(scale)
        let scaledW = rocket.size.width * scale
        let scaledH = rocket.size.height * scale
        let spawnX = player.position.x
        let spawnY = player.position.y + player.size.height / 2 + scaledH / 2
        rocket.position = CGPoint(x: spawnX, y: spawnY)
        rocket.name = "playerRocket"
        rocket.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: scaledW, height: scaledH))
        rocket.physicsBody?.isDynamic = false
        rocket.physicsBody?.usesPreciseCollisionDetection = true
        rocket.physicsBody?.categoryBitMask = categoryPlayerRocket
        rocket.physicsBody?.contactTestBitMask = categoryEnemy
        rocket.physicsBody?.collisionBitMask = 0
        rocket.zPosition = 15
        rocket.userData = ["spawnTime": lastUpdateTime, "heading": 0.0]  // 0 = omhoog (asset staat al goed)
        addChild(rocket)
    }

    private func addBullet(at basePos: CGPoint, offsetX: CGFloat, imageName: String = "bullet1", angle: CGFloat? = nil) {
        let bullet = SKSpriteNode(imageNamed: imageName)
        let rad = angle ?? 0
        bullet.zRotation = .pi / 2 - rad  // bullets asset; -rad zodat neus in vliegrichting wijst
        bullet.xScale = playerBulletSize.height / bullet.size.width
        bullet.yScale = playerBulletSize.width / bullet.size.height
        bullet.position = CGPoint(
            x: basePos.x + offsetX,
            y: basePos.y + player.size.height / 2 + playerBulletSize.height / 2
        )
        bullet.name = "playerBullet"
        bullet.physicsBody = SKPhysicsBody(rectangleOf: playerBulletSize)
        bullet.physicsBody?.isDynamic = false
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        bullet.physicsBody?.categoryBitMask = categoryPlayerBullet
        bullet.physicsBody?.contactTestBitMask = categoryEnemy
        bullet.physicsBody?.collisionBitMask = 0
        bullet.zPosition = 15
        addChild(bullet)
        if let a = angle {
            bullet.userData = ["angle": a]
        } else {
            let distance = size.height + playerBulletSize.height - bullet.position.y
            let duration = max(0.3, distance / bulletSpeed)
            let move = SKAction.moveTo(y: size.height + playerBulletSize.height, duration: duration)
            bullet.run(SKAction.sequence([move, SKAction.removeFromParent()]))
        }
    }

    private func fireEnemyBullet(from enemy: SKSpriteNode) {
        guard enemy.parent != nil else { return }
        let bullet = SKSpriteNode(imageNamed: "bullet4")
        // Onderkant van vijand (frame = zichtbare bbox, werkt bij elke rotatie)
        let enemyBottom = enemy.frame.minY
        bullet.position = CGPoint(x: enemy.position.x, y: enemyBottom - enemyBulletSize.height / 2)
        bullet.xScale = enemyBulletSize.width / bullet.size.width
        bullet.yScale = enemyBulletSize.height / bullet.size.height
        bullet.name = "enemyBullet"
        bullet.physicsBody = SKPhysicsBody(rectangleOf: enemyBulletSize)
        bullet.physicsBody?.isDynamic = false
        bullet.physicsBody?.categoryBitMask = categoryEnemyBullet
        bullet.physicsBody?.contactTestBitMask = categoryPlayer
        bullet.physicsBody?.collisionBitMask = 0
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        bullet.zPosition = 15
        addChild(bullet)
        let dy: CGFloat = size.height + 100
        let duration = max(0.5, dy / enemyBulletSpeed)
        let move = SKAction.moveBy(x: 0, y: -dy, duration: duration)  // omlaag naar speler
        bullet.run(SKAction.sequence([move, SKAction.removeFromParent()]))
    }

    private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "enemy1")
        let scale: CGFloat = 0.5  // 50% kleiner
        enemy.setScale(scale)
        let scaledW = enemy.size.width * scale
        let scaledH = enemy.size.height * scale
        let halfW = scaledW / 2
        let minX = halfW
        let maxX = size.width - halfW
        let gap: CGFloat = 40
        var existing: [(x: CGFloat, halfW: CGFloat)] = []
        enumerateChildNodes(withName: "enemy") { node, _ in
            let w: CGFloat
            if let sprite = node as? SKSpriteNode {
                w = sprite.size.width * abs(sprite.xScale)
            } else {
                w = node.frame.width
            }
            existing.append((node.position.x, w / 2))
        }
        let step: CGFloat = 25
        var validX: [CGFloat] = []
        var cx = minX
        while cx <= maxX {
            let ok = existing.allSatisfy { abs(cx - $0.x) >= halfW + $0.halfW + gap }
            if ok { validX.append(cx) }
            cx += step
        }
        guard let x = validX.randomElement() else { return }
        enemy.position = CGPoint(x: x, y: size.height + scaledH)
        enemy.name = "enemy"
        enemy.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: scaledW, height: scaledH))
        enemy.physicsBody?.isDynamic = false
        enemy.physicsBody?.categoryBitMask = categoryEnemy
        enemy.physicsBody?.contactTestBitMask = categoryPlayer | categoryPlayerBullet | categoryPlayerRocket
        enemy.physicsBody?.collisionBitMask = 0
        enemy.zPosition = 15
        enemy.userData = NSMutableDictionary()
        (enemy.userData as? NSMutableDictionary)?["enemyType"] = "enemy1"
        addChild(enemy)

        // Langzame draai: sommige linksom, andere rechtsom
        let rotDuration = TimeInterval.random(in: 3...5.5)  // net iets sneller draaien
        let rotAngle: CGFloat = Bool.random() ? .pi * 2 : -.pi * 2  // linksom of rechtsom
        let rotate = SKAction.rotate(byAngle: rotAngle, duration: rotDuration)
        enemy.run(SKAction.repeatForever(rotate), withKey: "enemyRotate")

        let duration = max(3.0, 5.0 - TimeInterval(waveIndex) * 0.3)
        let move = SKAction.moveTo(y: -scaledH, duration: duration)
        enemy.run(SKAction.sequence([move, SKAction.removeFromParent()]))

        let wait = SKAction.wait(forDuration: enemyFireInterval)
        let shoot = SKAction.run { [weak self, weak enemy] in
            guard let self = self, let enemy = enemy, enemy.parent != nil else { return }
            self.fireEnemyBullet(from: enemy)
        }
        enemy.run(SKAction.repeatForever(SKAction.sequence([wait, shoot])), withKey: "enemyShoot")
    }

    /// Spawnt een formatie alienplanes (V of lijn) die samen omlaag vliegen.
    private func spawnEnemyFormation() {
        let ref = SKSpriteNode(imageNamed: "alienplane")
        let halfW = ref.size.width / 2
        let halfH = ref.size.height / 2
        let formationHalfExtent = formationSpacing * 2 + halfW
        let minCenterX = formationHalfExtent
        let maxCenterX = size.width - formationHalfExtent
        let centerX = maxCenterX >= minCenterX ? CGFloat.random(in: minCenterX...maxCenterX) : size.width / 2
        let topY = size.height + halfH + 20

        // Formaties: 0 = V (5), 1 = horizontale lijn (4), 2 = kleine V (3)
        let formationType = Int.random(in: 0...2)
        let positions: [(x: CGFloat, y: CGFloat)]
        switch formationType {
        case 0:
            // V-vorm: midden voor, links/rechts achter
            positions = [
                (centerX, topY),
                (centerX - formationSpacing, topY - formationSpacing * 0.6),
                (centerX + formationSpacing, topY - formationSpacing * 0.6),
                (centerX - formationSpacing * 2, topY - formationSpacing * 1.2),
                (centerX + formationSpacing * 2, topY - formationSpacing * 1.2)
            ]
        case 1:
            // Horizontale lijn
            positions = [
                (centerX - formationSpacing * 1.5, topY),
                (centerX - formationSpacing * 0.5, topY),
                (centerX + formationSpacing * 0.5, topY),
                (centerX + formationSpacing * 1.5, topY)
            ]
        default:
            // Kleine V (3)
            positions = [
                (centerX, topY),
                (centerX - formationSpacing, topY - formationSpacing * 0.5),
                (centerX + formationSpacing, topY - formationSpacing * 0.5)
            ]
        }

        let duration = max(3.2, 5.2 - TimeInterval(waveIndex) * 0.25)
        for (i, pos) in positions.enumerated() {
            let enemy = SKSpriteNode(imageNamed: "alienplane")
            enemy.zRotation = .pi  // asset wijst omhoog; 180° zodat ze omlaag vliegen en omlaag schieten
            enemy.position = CGPoint(x: pos.x, y: pos.y)
            enemy.name = "enemy"
            enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
            enemy.physicsBody?.isDynamic = false
            enemy.physicsBody?.categoryBitMask = categoryEnemy
            enemy.physicsBody?.contactTestBitMask = categoryPlayer | categoryPlayerBullet | categoryPlayerRocket
            enemy.physicsBody?.collisionBitMask = 0
            enemy.zPosition = 15
            enemy.userData = NSMutableDictionary()
            (enemy.userData as? NSMutableDictionary)?["enemyType"] = "alienplane"
            addChild(enemy)

            let targetY: CGFloat = -enemy.size.height - CGFloat(i) * 20
            let move = SKAction.moveTo(y: targetY, duration: duration)
            enemy.run(SKAction.sequence([move, SKAction.removeFromParent()]))

            let wait = SKAction.wait(forDuration: enemyFireInterval)
            let shoot = SKAction.run { [weak self, weak enemy] in
                guard let self = self, let enemy = enemy, enemy.parent != nil else { return }
                self.fireEnemyBullet(from: enemy)
            }
            enemy.run(SKAction.repeatForever(SKAction.sequence([wait, shoot])), withKey: "enemyShoot")
        }
    }

    private func trySpawnPowerup(at position: CGPoint) {
        if Float.random(in: 0...1) > powerupDropChance { return }
        let pwSize = CGSize(width: 32, height: 32)
        let choice = Int.random(in: 0..<5)  // 0=triple, 1=spread, 2=rocket, 3=laser, 4=wingman
        let pw: SKSpriteNode
        let name: String
        switch choice {
        case 0:
            pw = SKSpriteNode(imageNamed: "powerup1")
            name = "powerupTriple"
        case 1:
            pw = SKSpriteNode(imageNamed: "powerup2")
            name = "powerupSpread"
        case 2:
            pw = SKSpriteNode(imageNamed: "powerup4")
            name = "powerupRocket"
        case 3:
            pw = SKSpriteNode(imageNamed: "powerup3")
            name = "powerupLaser"
        default:
            pw = SKSpriteNode(imageNamed: "powerup5")
            name = "powerupWingman"
        }
        if pw.texture != nil {
            pw.size = pwSize
        }
        pw.position = position
        pw.name = name
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

    private func activateWingmen() {
        wingmanUntil = lastUpdateTime + wingmanDuration
        if leftWingmanNode == nil, let pl = player {
            let scale: CGFloat = 0.45
            let left = SKSpriteNode(imageNamed: "playerShip")
            left.setScale(scale)
            left.position = CGPoint(x: -wingmanOffset, y: 0)
            left.zPosition = -2
            left.name = "wingmanLeft"
            pl.addChild(left)
            leftWingmanNode = left
            let right = SKSpriteNode(imageNamed: "playerShip")
            right.setScale(scale)
            right.position = CGPoint(x: wingmanOffset, y: 0)
            right.zPosition = -2
            right.name = "wingmanRight"
            pl.addChild(right)
            rightWingmanNode = right
        }
    }

    private func fireWingmanBullets() {
        let leftPos = CGPoint(x: player.position.x - wingmanOffset, y: player.position.y)
        let rightPos = CGPoint(x: player.position.x + wingmanOffset, y: player.position.y)
        addBullet(at: leftPos, offsetX: 0, imageName: "bullet1")
        addBullet(at: rightPos, offsetX: 0, imageName: "bullet1")
    }

    private func activateLaser() {
        laserUntil = lastUpdateTime + laserDuration
        if laserBeamNode == nil {
            let beam = SKSpriteNode(color: SKColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.7), size: CGSize(width: 12, height: 100))
            beam.name = "laserBeam"
            beam.zPosition = 14
            addChild(beam)
            laserBeamNode = beam
        }
    }

    private func updateLaserBeam(dt: TimeInterval) {
        guard let beam = laserBeamNode, let pl = player, pl.parent != nil else { return }
        let topY = size.height
        let fromY = pl.position.y + pl.size.height / 2
        let h = max(20, topY - fromY)
        beam.size = CGSize(width: 12, height: h)
        beam.position = CGPoint(x: pl.position.x, y: fromY + h / 2)
        let beamRect = beam.frame
        var hitEnemies: [SKNode] = []
        enumerateChildNodes(withName: "enemy") { enemy, _ in
            if beamRect.intersects(enemy.frame) { hitEnemies.append(enemy) }
        }
        for enemy in hitEnemies {
            let pos = enemy.position
            let color = debrisColor(for: enemy)
            enemy.removeFromParent()
            addEnemyDebris(at: pos, color: color)
            addScore(bulletScore)
            trySpawnPowerup(at: pos)
        }
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

    /// Kleur voor brokstukken op basis van vijandtype (userData["enemyType"]).
    private func debrisColor(for enemy: SKNode?) -> SKColor {
        guard let type = enemy?.userData?["enemyType"] as? String else { return enemy1DebrisColor }
        return type == "alienplane" ? alienplaneDebrisColor : enemy1DebrisColor
    }

    /// Vijand klapt uit elkaar in gekleurde brokstukken die uiteenvliegen en omlaag vallen.
    private func addEnemyDebris(at position: CGPoint, color: SKColor) {
        let pieceCount = 10
        let baseSize: CGFloat = 8
        let spread: CGFloat = 60
        let fallDuration: TimeInterval = 0.9
        for i in 0..<pieceCount {
            let size = baseSize + CGFloat.random(in: -2...6)
            let rect = CGRect(x: -size/2, y: -size/2, width: size, height: size)
            let piece = SKShapeNode(rect: rect)
            piece.fillColor = color
            piece.strokeColor = .clear
            piece.position = position
            piece.zPosition = 49
            addChild(piece)
            let angle = CGFloat(i) / CGFloat(pieceCount) * .pi * 2 + CGFloat.random(in: 0...0.5)
            let dx = cos(angle) * CGFloat.random(in: spread * 0.4...spread)
            let dy = -CGFloat.random(in: spread * 0.6...spread * 1.2)
            let move = SKAction.moveBy(x: dx, y: dy, duration: fallDuration)
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -2...2) * .pi, duration: fallDuration)
            let fade = SKAction.fadeOut(withDuration: fallDuration * 0.6)
            let group = SKAction.group([move, rotate])
            let seq = SKAction.sequence([group, SKAction.wait(forDuration: 0.1), fade, SKAction.removeFromParent()])
            piece.run(seq)
        }
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
            let color = debrisColor(for: enemy)
            bullet?.removeFromParent()
            enemy?.removeFromParent()
            addEnemyDebris(at: hitPos, color: color)
            addScore(bulletScore)
            trySpawnPowerup(at: hitPos)
        }

        // Player rocket vs Enemy (meer damage)
        if (maskA == categoryPlayerRocket && maskB == categoryEnemy) || (maskA == categoryEnemy && maskB == categoryPlayerRocket) {
            let rocket = maskA == categoryPlayerRocket ? bodyA.node : bodyB.node
            let enemy = maskA == categoryEnemy ? bodyA.node : bodyB.node
            let hitPos = enemy?.position ?? rocket?.position ?? .zero
            let color = debrisColor(for: enemy)
            rocket?.removeFromParent()
            enemy?.removeFromParent()
            addEnemyDebris(at: hitPos, color: color)
            addScore(rocketScore)
            trySpawnPowerup(at: hitPos)
        }

        // Powerup vs Player
        if (maskA == categoryPowerup && maskB == categoryPlayer) || (maskA == categoryPlayer && maskB == categoryPowerup) {
            let pw = maskA == categoryPowerup ? bodyA.node : bodyB.node
            let name = pw?.name ?? ""
            pw?.removeFromParent()
            if name == "powerupRocket" {
                rocketUntil = lastUpdateTime + rocketDuration
            } else if name == "powerupSpread" {
                spreadShotUntil = lastUpdateTime + spreadShotDuration
            } else if name == "powerupLaser" {
                activateLaser()
            } else if name == "powerupWingman" {
                activateWingmen()
            } else {
                tripleShotUntil = lastUpdateTime + tripleShotDuration
            }
        }

        // Enemy bullet vs Player – 20% health schade per kogel
        if (maskA == categoryEnemyBullet && maskB == categoryPlayer) || (maskA == categoryPlayer && maskB == categoryEnemyBullet) {
            let bullet = maskA == categoryEnemyBullet ? bodyA.node : bodyB.node
            bullet?.removeFromParent()
            if lastUpdateTime >= invincibleUntil { playerHitByBullet() }
        }

        // Player vs Enemy (ram) – vliegtuig raakt je = één leven eraf (na 3x game over)
        if (maskA == categoryPlayer && maskB == categoryEnemy) || (maskA == categoryEnemy && maskB == categoryPlayer) {
            let enemy = maskA == categoryEnemy ? bodyA.node : bodyB.node
            let pos = enemy?.position ?? .zero
            let color = debrisColor(for: enemy)
            enemy?.removeFromParent()
            addEnemyDebris(at: pos, color: color)
            invincibleUntil = lastUpdateTime + invincibilityDuration
            loseOneLife()
        }
    }

    /// Kogel raakt speler: 20% health eraf; bij 0 verlies je een leven.
    private func playerHitByBullet() {
        invincibleUntil = lastUpdateTime + invincibilityDuration
        playerHealth -= 20
        playerHealthBar?.xScale = max(0, playerHealth / 100)
        if playerHealth <= 0 {
            loseOneLife()
        }
    }

    /// Eén leven (vliegtuigje) eraf; health reset; bij 0 levens pas game over.
    private func loseOneLife() {
        lives -= 1
        playerHealth = 100
        playerHealthBar?.xScale = 1.0
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
