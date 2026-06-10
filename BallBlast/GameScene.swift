import SpriteKit
import UIKit

/// The Ball Blast playfield. Physics is simulated manually for the classic
/// arcade feel: balls follow fixed-height bounces regardless of impact speed.
final class GameScene: SKScene {

    enum Phase {
        case ready      // waiting for first touch
        case running
        case won
        case lost
    }

    let config: LevelConfig
    let loadout: PlayerLoadout

    var onStarted: (() -> Void)?
    var onRunCoinsChanged: ((Int) -> Void)?
    var onProgressChanged: ((Double) -> Void)?
    var onGameEnded: ((_ victory: Bool, _ runCoins: Int) -> Void)?

    private(set) var phase: Phase = .ready

    // MARK: - Entities

    private final class Ball {
        let node: SKNode
        let shape: SKShapeNode
        let label: SKLabelNode
        var hp: Int
        let maxHP: Int
        let tier: Int
        let radius: CGFloat
        var vx: CGFloat
        var vy: CGFloat

        init(node: SKNode, shape: SKShapeNode, label: SKLabelNode,
             hp: Int, tier: Int, radius: CGFloat, vx: CGFloat, vy: CGFloat) {
            self.node = node
            self.shape = shape
            self.label = label
            self.hp = hp
            self.maxHP = hp
            self.tier = tier
            self.radius = radius
            self.vx = vx
            self.vy = vy
        }
    }

    private var balls: [Ball] = []
    private var bullets: [SKSpriteNode] = []
    private let cannon = SKNode()

    // MARK: - Tuning

    private let gravity: CGFloat = 1500
    private let bulletSpeed: CGFloat = 1150
    private let groundHeight: CGFloat = 120
    private let cannonHitRadius: CGFloat = 26
    private static let tierRadii: [CGFloat] = [18, 28, 42, 62]
    private static let tierBounceSpeeds: [CGFloat] = [760, 930, 1100, 1280]
    private static let palette: [SKColor] = [
        SKColor(red: 0.93, green: 0.35, blue: 0.38, alpha: 1),
        SKColor(red: 0.30, green: 0.69, blue: 0.94, alpha: 1),
        SKColor(red: 0.55, green: 0.80, blue: 0.35, alpha: 1),
        SKColor(red: 0.95, green: 0.62, blue: 0.26, alpha: 1),
        SKColor(red: 0.71, green: 0.46, blue: 0.91, alpha: 1),
        SKColor(red: 0.93, green: 0.45, blue: 0.74, alpha: 1),
        SKColor(red: 0.36, green: 0.83, blue: 0.74, alpha: 1),
    ]

    // MARK: - Runtime state

    private var lastUpdateTime: TimeInterval = 0
    private var fireAccumulator: Double = 0
    private var spawnAccumulator: Double
    private var spawnedCount = 0
    private var spawnFromLeft = true
    private var cannonTargetX: CGFloat = 0

    private var runCoins = 0
    private var destroyedHP = 0
    private let totalHP: Int

    private let popHaptic = UIImpactFeedbackGenerator(style: .light)
    private let bigHaptic = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Setup

    init(size: CGSize, config: LevelConfig, loadout: PlayerLoadout) {
        self.config = config
        self.loadout = loadout
        self.totalHP = config.totalHPPool
        // Start "charged" so the first ball appears immediately.
        self.spawnAccumulator = config.spawnInterval
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        buildGround()
        buildCannon()
        cannonTargetX = size.width / 2
        cannon.position = CGPoint(x: size.width / 2, y: groundHeight + 13)
        popHaptic.prepare()
    }

    private func buildGround() {
        let ground = SKSpriteNode(color: SKColor(red: 0.14, green: 0.15, blue: 0.26, alpha: 1),
                                  size: CGSize(width: 4000, height: groundHeight))
        ground.position = CGPoint(x: size.width / 2, y: groundHeight / 2)
        ground.zPosition = 10
        addChild(ground)

        let line = SKSpriteNode(color: SKColor(red: 0.27, green: 0.29, blue: 0.46, alpha: 1),
                                size: CGSize(width: 4000, height: 3))
        line.position = CGPoint(x: size.width / 2, y: groundHeight - 1.5)
        line.zPosition = 11
        addChild(line)
    }

    private func buildCannon() {
        let bodyColor = SKColor(red: 1.0, green: 0.8, blue: 0.15, alpha: 1)
        let darkColor = SKColor(red: 0.16, green: 0.16, blue: 0.22, alpha: 1)

        let barrel = SKShapeNode(rect: CGRect(x: -9, y: 8, width: 18, height: 38), cornerRadius: 5)
        barrel.fillColor = darkColor
        barrel.strokeColor = .clear
        cannon.addChild(barrel)

        let body = SKShapeNode(circleOfRadius: 24)
        body.fillColor = bodyColor
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 10)
        cannon.addChild(body)

        let visor = SKShapeNode(rect: CGRect(x: -14, y: 8, width: 28, height: 9), cornerRadius: 4.5)
        visor.fillColor = darkColor
        visor.strokeColor = .clear
        cannon.addChild(visor)

        for wx in [CGFloat(-16), CGFloat(16)] {
            let wheel = SKShapeNode(circleOfRadius: 11)
            wheel.fillColor = darkColor
            wheel.strokeColor = .clear
            wheel.position = CGPoint(x: wx, y: -2)
            cannon.addChild(wheel)

            let hub = SKShapeNode(circleOfRadius: 4)
            hub.fillColor = SKColor(white: 0.55, alpha: 1)
            hub.strokeColor = .clear
            hub.position = CGPoint(x: wx, y: -2)
            cannon.addChild(hub)
        }

        cannon.zPosition = 30
        addChild(cannon)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if phase == .ready {
            phase = .running
            onStarted?()
        }
        cannonTargetX = touch.location(in: self).x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        cannonTargetX = touch.location(in: self).x
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt: Double
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(currentTime - lastUpdateTime, 1.0 / 30.0)
        }
        lastUpdateTime = currentTime

        moveCannon(dt)
        guard phase == .running else { return }

        spawnIfNeeded(dt)
        fireIfNeeded(dt)
        updateBullets(dt)
        updateBalls(dt)
        resolveHits()
        checkVictory()
    }

    private func moveCannon(_ dt: Double) {
        let margin: CGFloat = 36
        let target = min(max(cannonTargetX, margin), size.width - margin)
        let x = cannon.position.x
        cannon.position.x = x + (target - x) * CGFloat(min(1.0, dt * 16))
    }

    private func spawnIfNeeded(_ dt: Double) {
        guard spawnedCount < config.ballCount else { return }
        spawnAccumulator += dt
        guard spawnAccumulator >= config.spawnInterval else { return }
        spawnAccumulator = 0
        spawnedCount += 1

        let radius = Self.tierRadii[config.ballTier]
        let x: CGFloat = spawnFromLeft ? 60 : size.width - 60
        let vx = CGFloat.random(in: 90...140) * (spawnFromLeft ? 1 : -1)
        spawnFromLeft.toggle()

        let ball = makeBall(tier: config.ballTier,
                            hp: config.ballHP,
                            position: CGPoint(x: x, y: size.height + radius + 10),
                            vx: vx, vy: 0)
        balls.append(ball)
    }

    private func fireIfNeeded(_ dt: Double) {
        fireAccumulator += dt
        let interval = 1.0 / loadout.shotsPerSecond
        var volleys = 0
        while fireAccumulator >= interval && volleys < 4 {
            fireAccumulator -= interval
            fireVolley()
            volleys += 1
        }
    }

    private func fireVolley() {
        let streams = loadout.bulletStreams
        let spacing: CGFloat = 14
        let startX = cannon.position.x - spacing * CGFloat(streams - 1) / 2

        for i in 0..<streams {
            let bullet = SKSpriteNode(color: SKColor(red: 1, green: 0.92, blue: 0.5, alpha: 1),
                                      size: CGSize(width: 5, height: 16))
            bullet.position = CGPoint(x: startX + CGFloat(i) * spacing,
                                      y: cannon.position.y + 44)
            bullet.zPosition = 15
            addChild(bullet)
            bullets.append(bullet)
        }
    }

    private func updateBullets(_ dt: Double) {
        var alive: [SKSpriteNode] = []
        for bullet in bullets {
            bullet.position.y += bulletSpeed * CGFloat(dt)
            if bullet.position.y > size.height + 30 {
                bullet.removeFromParent()
            } else {
                alive.append(bullet)
            }
        }
        bullets = alive
    }

    private func updateBalls(_ dt: Double) {
        let dtF = CGFloat(dt)
        for ball in balls {
            ball.vy -= gravity * dtF
            var x = ball.node.position.x + ball.vx * dtF
            var y = ball.node.position.y + ball.vy * dtF

            if x - ball.radius < 0 {
                x = ball.radius
                ball.vx = abs(ball.vx)
            } else if x + ball.radius > size.width {
                x = size.width - ball.radius
                ball.vx = -abs(ball.vx)
            }

            if y - ball.radius <= groundHeight && ball.vy < 0 {
                y = groundHeight + ball.radius
                ball.vy = Self.tierBounceSpeeds[ball.tier]
            }

            ball.node.position = CGPoint(x: x, y: y)
        }
    }

    private func resolveHits() {
        // Bullets vs balls.
        var remaining: [SKSpriteNode] = []
        for bullet in bullets {
            var hit = false
            for ball in balls where ball.hp > 0 {
                let dx = bullet.position.x - ball.node.position.x
                let dy = bullet.position.y - ball.node.position.y
                let reach = ball.radius + 9
                if dx * dx + dy * dy <= reach * reach {
                    ball.hp -= loadout.bulletDamage
                    ball.label.text = shortNumber(max(0, ball.hp))
                    hit = true
                    break
                }
            }
            if hit {
                bullet.removeFromParent()
            } else {
                remaining.append(bullet)
            }
        }
        bullets = remaining

        // Pop dead balls; split the bigger tiers in two.
        var survivors: [Ball] = []
        var children: [Ball] = []
        var anyDestroyed = false
        for ball in balls {
            if ball.hp <= 0 {
                anyDestroyed = true
                destroyedHP += ball.maxHP
                awardCoins(for: ball)
                popEffect(at: ball.node.position, color: ball.shape.fillColor, radius: ball.radius)
                if ball.tier >= 2 {
                    bigHaptic.impactOccurred()
                } else {
                    popHaptic.impactOccurred()
                }

                if ball.tier > 0 {
                    let childHP = max(1, ball.maxHP / 2)
                    let speed = CGFloat.random(in: 80...130)
                    for direction in [CGFloat(-1), CGFloat(1)] {
                        let child = makeBall(tier: ball.tier - 1,
                                             hp: childHP,
                                             position: ball.node.position,
                                             vx: speed * direction,
                                             vy: 420)
                        children.append(child)
                    }
                }
                ball.node.removeFromParent()
            } else {
                survivors.append(ball)
            }
        }
        balls = survivors + children
        if anyDestroyed {
            onProgressChanged?(min(1.0, Double(destroyedHP) / Double(totalHP)))
        }

        // Balls vs cannon: one touch and it's over.
        let cannonCenter = CGPoint(x: cannon.position.x, y: cannon.position.y + 10)
        for ball in balls {
            let dx = ball.node.position.x - cannonCenter.x
            let dy = ball.node.position.y - cannonCenter.y
            let reach = ball.radius + cannonHitRadius
            if dx * dx + dy * dy < reach * reach {
                lose()
                return
            }
        }
    }

    private func checkVictory() {
        guard phase == .running,
              spawnedCount == config.ballCount,
              balls.isEmpty else { return }
        phase = .won
        run(.sequence([.wait(forDuration: 0.6),
                       .run { [weak self] in
                           guard let self else { return }
                           self.onGameEnded?(true, self.runCoins)
                       }]))
    }

    private func lose() {
        guard phase == .running else { return }
        phase = .lost
        bigHaptic.impactOccurred()
        popEffect(at: cannon.position,
                  color: SKColor(red: 1.0, green: 0.8, blue: 0.15, alpha: 1),
                  radius: 40)
        cannon.isHidden = true
        run(.sequence([.wait(forDuration: 0.8),
                       .run { [weak self] in
                           guard let self else { return }
                           self.onGameEnded?(false, self.runCoins)
                       }]))
    }

    // MARK: - Helpers

    private func makeBall(tier: Int, hp: Int, position: CGPoint, vx: CGFloat, vy: CGFloat) -> Ball {
        let radius = Self.tierRadii[tier]
        let color = Self.palette[(config.number - 1 + tier) % Self.palette.count]

        let container = SKNode()
        container.position = position
        container.zPosition = 20

        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = color
        shape.strokeColor = SKColor(white: 0, alpha: 0.25)
        shape.lineWidth = 3
        container.addChild(shape)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = shortNumber(hp)
        label.fontSize = max(12, radius * 0.55)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        addChild(container)
        return Ball(node: container, shape: shape, label: label,
                    hp: hp, tier: tier, radius: radius, vx: vx, vy: vy)
    }

    private func awardCoins(for ball: Ball) {
        let value = max(1, Int((Double(ball.maxHP) * Balance.coinsPerHP * loadout.coinMultiplier).rounded()))
        runCoins += value
        onRunCoinsChanged?(runCoins)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "+\(shortNumber(value))"
        label.fontSize = 17
        label.fontColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        label.position = ball.node.position
        label.zPosition = 40
        addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 46, duration: 0.6)
        rise.timingMode = .easeOut
        label.run(.sequence([.group([rise, .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
    }

    private func popEffect(at point: CGPoint, color: SKColor, radius: CGFloat) {
        for _ in 0..<7 {
            let bit = SKShapeNode(circleOfRadius: max(3, radius * 0.14))
            bit.fillColor = color
            bit.strokeColor = .clear
            bit.position = point
            bit.zPosition = 40
            addChild(bit)

            let angle = CGFloat.random(in: 0..<(2 * .pi))
            let distance = CGFloat.random(in: radius...(radius * 2.2))
            let move = SKAction.moveBy(x: cos(angle) * distance,
                                       y: sin(angle) * distance + 20,
                                       duration: 0.35)
            move.timingMode = .easeOut
            bit.run(.sequence([.group([move, .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
    }
}
