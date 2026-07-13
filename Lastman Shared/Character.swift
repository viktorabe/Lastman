//
//  Character.swift
//  Lastman
//
//  Entité de base joueur + bots : PV, node stickman, physics body, intents.
//  Le state logique vit ici (source de vérité) ; le SKNode n'est que le rendu.
//

import SpriteKit

/// Node porteur d'une référence vers l'entité, pour remonter du contact physique à la logique.
final class CharacterNode: SKNode {
    weak var character: Character?
}

final class Character {

    let displayName: String
    let isPlayer: Bool
    let color: SKColor
    let node = CharacterNode()

    private(set) var hp: CGFloat = GameConfig.maxHP
    var isAlive: Bool { hp > 0 }
    var hpFraction: CGFloat { max(0, hp / GameConfig.maxHP) }
    var position: CGPoint { node.position }
    weak var lastDamageSource: Character?

    /// Appelé une seule fois quand les PV tombent à 0. Branché par GameScene.
    var onDeath: ((Character) -> Void)?

    // MARK: Intents (remplis par PlayerController ou BotBrain, consommés par les systèmes)
    var moveIntent: CGVector = .zero      // amplitude 0...1
    var aimIntent: CGVector?              // direction de tir souhaitée, nil = ne tire pas
    var fireCooldown: TimeInterval = 0
    private var speedBoostRemaining: TimeInterval = 0
    private var shieldRemaining: TimeInterval = 0
    private var shieldRing: SKShapeNode!
    var isSpeedBoostActive: Bool { speedBoostRemaining > 0 }
    var isShieldActive: Bool { shieldRemaining > 0 }
    var speedBoostTimeRemaining: TimeInterval { speedBoostRemaining }
    var shieldTimeRemaining: TimeInterval { shieldRemaining }

    // MARK: État buisson (géré par BushSystem)
    var currentBushID: Int?
    var lastShotTime: TimeInterval = -10
    var isRevealed = true
    /// Caché au sens gameplay : dans un buisson et pas révélé (SPEC §6.3).
    var isConcealed: Bool { currentBushID != nil && !isRevealed }

    // MARK: Rendu
    private let figure = SKNode()
    private let leftLegPivot = SKNode()
    private let rightLegPivot = SKNode()
    private let aimIndicator = SKNode()
    private var hpBarFill: SKShapeNode!
    private var strokeNodes: [SKShapeNode] = []
    private var isRunAnimActive = false

    init(name: String, isPlayer: Bool, color: SKColor, position: CGPoint) {
        self.displayName = name
        self.isPlayer = isPlayer
        self.color = color
        node.character = self
        node.position = position
        node.zPosition = 10
        buildFigure()
        buildHPBar()
        buildShieldRing()
        buildPhysics()
        node.setScale(GameConfig.characterVisualScale)
    }

    // MARK: - Construction du stickman (trait fin, lisible petit — SPEC §8)

    private func line(from: CGPoint, to: CGPoint, width: CGFloat = 2.2) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let shape = SKShapeNode(path: path)
        shape.strokeColor = color
        shape.lineWidth = width
        shape.lineCap = .round
        return shape
    }

    private func buildFigure() {
        // Tête
        let head = SKShapeNode(circleOfRadius: 5)
        head.position = CGPoint(x: 0, y: 12)
        head.strokeColor = color
        head.lineWidth = 2.2
        head.fillColor = .clear

        // Tronc et bras
        let torso = line(from: CGPoint(x: 0, y: 7), to: CGPoint(x: 0, y: -4))
        let armL = line(from: CGPoint(x: 0, y: 4), to: CGPoint(x: -6, y: -1))
        let armR = line(from: CGPoint(x: 0, y: 4), to: CGPoint(x: 6, y: -1))

        // Jambes sur pivots pour l'animation de course
        leftLegPivot.position = CGPoint(x: 0, y: -4)
        rightLegPivot.position = CGPoint(x: 0, y: -4)
        let legL = line(from: .zero, to: CGPoint(x: -4, y: -11))
        let legR = line(from: .zero, to: CGPoint(x: 4, y: -11))
        leftLegPivot.addChild(legL)
        rightLegPivot.addChild(legR)

        strokeNodes = [head, torso, armL, armR, legL, legR]

        figure.addChild(torso)
        figure.addChild(armL)
        figure.addChild(armR)
        figure.addChild(leftLegPivot)
        figure.addChild(rightLegPivot)
        figure.addChild(head)
        node.addChild(figure)

        // Indicateur de visée : petit canon qui pointe la direction de tir
        let barrel = line(from: CGPoint(x: 10, y: 0), to: CGPoint(x: 20, y: 0), width: 2.6)
        barrel.alpha = 0.9
        aimIndicator.addChild(barrel)
        node.addChild(aimIndicator)
    }

    private func buildHPBar() {
        let barWidth: CGFloat = 28
        let bg = SKShapeNode(rectOf: CGSize(width: barWidth, height: 4), cornerRadius: 2)
        bg.position = CGPoint(x: 0, y: 24)
        bg.fillColor = SKColor(white: 1, alpha: 0.15)
        bg.strokeColor = .clear
        node.addChild(bg)

        hpBarFill = SKShapeNode(rectOf: CGSize(width: barWidth, height: 4), cornerRadius: 2)
        hpBarFill.position = .zero
        hpBarFill.fillColor = color
        hpBarFill.strokeColor = .clear
        bg.addChild(hpBarFill)
    }

    private func buildShieldRing() {
        shieldRing = SKShapeNode(circleOfRadius: GameConfig.characterRadius + 7)
        shieldRing.strokeColor = SKColor(red: 0.62, green: 0.85, blue: 1.0, alpha: 0.95)
        shieldRing.fillColor = SKColor(red: 0.32, green: 0.62, blue: 1.0, alpha: 0.10)
        shieldRing.lineWidth = 2
        shieldRing.alpha = 0
        shieldRing.zPosition = -1
        node.addChild(shieldRing)
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(circleOfRadius: GameConfig.characterRadius)
        body.allowsRotation = false
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = isPlayer ? PhysicsCategory.player : PhysicsCategory.bot
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.anyCharacter | PhysicsCategory.breakable
        body.contactTestBitMask = PhysicsCategory.none
        node.physicsBody = body
    }

    // MARK: - Boucle

    /// Applique le moveIntent au physics body. Réactif, léger easing (SPEC §6.1).
    func applyMovement(dt: TimeInterval) {
        guard isAlive, let body = node.physicsBody else { return }
        speedBoostRemaining = max(0, speedBoostRemaining - dt)
        shieldRemaining = max(0, shieldRemaining - dt)
        let speedMultiplier = speedBoostRemaining > 0 ? GameConfig.speedBoostMultiplier : 1
        let target = moveIntent * (GameConfig.playerSpeed * speedMultiplier)
        body.velocity = body.velocity.lerped(to: target, t: GameConfig.velocityLerpRate * CGFloat(dt))

        updateShieldVisual()
        updateRunAnimation(speed: body.velocity.length)
        updateFacing()
    }

    private func updateFacing() {
        // Le canon suit la visée si on vise, sinon la direction de déplacement.
        let dir = aimIntent ?? (moveIntent.length > 0.1 ? moveIntent : nil)
        if let dir, dir.length > 0.05 {
            aimIndicator.zRotation = dir.angle
            aimIndicator.alpha = 0.9
        }
    }

    private func updateRunAnimation(speed: CGFloat) {
        let running = speed > 25
        guard running != isRunAnimActive else { return }
        isRunAnimActive = running

        if running {
            let swing: CGFloat = 0.55
            let half = 0.14
            let swingL = SKAction.repeatForever(.sequence([
                .rotate(toAngle: swing, duration: half, shortestUnitArc: true),
                .rotate(toAngle: -swing, duration: half, shortestUnitArc: true),
            ]))
            let swingR = SKAction.repeatForever(.sequence([
                .rotate(toAngle: -swing, duration: half, shortestUnitArc: true),
                .rotate(toAngle: swing, duration: half, shortestUnitArc: true),
            ]))
            leftLegPivot.run(swingL, withKey: "run")
            rightLegPivot.run(swingR, withKey: "run")
            let bob = SKAction.repeatForever(.sequence([
                .moveBy(x: 0, y: 1.5, duration: half),
                .moveBy(x: 0, y: -1.5, duration: half),
            ]))
            figure.run(bob, withKey: "bob")
        } else {
            leftLegPivot.removeAction(forKey: "run")
            rightLegPivot.removeAction(forKey: "run")
            figure.removeAction(forKey: "bob")
            leftLegPivot.run(.rotate(toAngle: 0, duration: 0.1, shortestUnitArc: true))
            rightLegPivot.run(.rotate(toAngle: 0, duration: 0.1, shortestUnitArc: true))
            figure.run(.moveTo(y: 0, duration: 0.1))
        }
    }

    // MARK: - Dégâts et soin

    @discardableResult
    func takeDamage(_ amount: CGFloat, source: Character? = nil, withFX: Bool = true) -> Bool {
        guard isAlive else { return false }
        if withFX, shieldRemaining > 0, amount > 0 {
            shieldRemaining = 0
            updateShieldVisual()
            flashShieldBreak()
            return false
        }
        lastDamageSource = source
        hp = max(0, hp - amount)
        updateHPBar()
        if withFX { flashHit() }
        if hp <= 0 { die() }
        return true
    }

    @discardableResult
    func heal(_ amount: CGFloat) -> Bool {
        guard isAlive, hp < GameConfig.maxHP else { return false }
        hp = min(GameConfig.maxHP, hp + amount)
        updateHPBar()
        flashHeal()
        return true
    }

    func applySpeedBoost(duration: TimeInterval) {
        guard isAlive else { return }
        speedBoostRemaining = max(speedBoostRemaining, duration)
        flashBoost()
    }

    func applyShield(duration: TimeInterval) {
        guard isAlive else { return }
        shieldRemaining = max(shieldRemaining, duration)
        updateShieldVisual()
        flashShield()
    }

    func applyImpulse(_ vector: CGVector) {
        guard isAlive, let body = node.physicsBody else { return }
        body.velocity = body.velocity + vector
    }

    private func updateHPBar() {
        let barWidth: CGFloat = 28
        hpBarFill.xScale = hpFraction
        hpBarFill.position = CGPoint(x: -barWidth * (1 - hpFraction) / 2, y: 0)
    }

    /// Flash blanc sur le corps touché (SPEC §8).
    private func flashHit() {
        for shape in strokeNodes {
            shape.strokeColor = .white
        }
        node.run(.sequence([
            .wait(forDuration: 0.08),
            .run { [weak self] in
                guard let self else { return }
                for shape in self.strokeNodes {
                    shape.strokeColor = self.color
                }
            },
        ]), withKey: "hitFlash")
    }

    private func flashHeal() {
        let healColor = SKColor(red: 0.52, green: 1.0, blue: 0.76, alpha: 1)
        flashBody(color: healColor, duration: 0.12, key: "healFlash")
    }

    private func flashBoost() {
        let boostColor = SKColor(red: 0.45, green: 0.72, blue: 1.0, alpha: 1)
        flashBody(color: boostColor, duration: 0.16, key: "boostFlash")
    }

    private func flashShield() {
        let shieldColor = SKColor(red: 0.62, green: 0.85, blue: 1.0, alpha: 1)
        flashBody(color: shieldColor, duration: 0.18, key: "shieldFlash")
    }

    private func flashShieldBreak() {
        shieldRing.run(.sequence([
            .group([
                .scale(to: 1.45, duration: 0.16),
                .fadeOut(withDuration: 0.16),
            ]),
            .scale(to: 1, duration: 0),
        ]), withKey: "shieldBreak")
    }

    private func updateShieldVisual() {
        guard shieldRing != nil else { return }
        let active = shieldRemaining > 0
        shieldRing.alpha = active ? 1 : 0
        if active, shieldRing.action(forKey: "shieldPulse") == nil {
            shieldRing.run(.repeatForever(.sequence([
                .scale(to: 1.08, duration: 0.45),
                .scale(to: 1.0, duration: 0.45),
            ])), withKey: "shieldPulse")
        } else if !active {
            shieldRing.removeAction(forKey: "shieldPulse")
            shieldRing.setScale(1)
        }
    }

    private func flashBody(color: SKColor, duration: TimeInterval, key: String) {
        for shape in strokeNodes {
            shape.strokeColor = color
        }
        node.run(.sequence([
            .wait(forDuration: duration),
            .run { [weak self] in
                guard let self else { return }
                for shape in self.strokeNodes {
                    shape.strokeColor = self.color
                }
            },
        ]), withKey: key)
    }

    private func die() {
        node.physicsBody = nil
        moveIntent = .zero
        aimIntent = nil
        leftLegPivot.removeAllActions()
        rightLegPivot.removeAllActions()
        figure.removeAllActions()
        onDeath?(self)

        // Animation de mort : petit sursaut puis fade (le poof est géré par FX).
        node.run(.sequence([
            .group([
                .scale(to: 1.25, duration: 0.1),
                .fadeAlpha(to: 0.6, duration: 0.1),
            ]),
            .group([
                .scale(to: 0.4, duration: 0.3),
                .fadeOut(withDuration: 0.3),
            ]),
            .removeFromParent(),
        ]))
    }

    /// Alpha vu à l'écran selon l'état caché (appelé par BushSystem).
    func updateConcealmentVisual() {
        guard isAlive else { return }
        if isPlayer {
            // Le joueur se voit toujours normalement (SPEC §6.3).
            node.alpha = 1
        } else {
            node.alpha = isConcealed ? GameConfig.bushHiddenAlpha : 1
        }
    }
}
