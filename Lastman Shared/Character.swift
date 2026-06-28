//
//  Character.swift
//  Lastman
//
//  Base commune au joueur et aux bots (SPEC §9). Porte les PV, le corps
//  physique, la barre de vie, l'indicateur de visée et le déplacement avec
//  easing. Le node est le rendu ; la logique (PV, état caché) vit ici.
//

import SpriteKit

class Character {

    let node: SKNode
    let isPlayer: Bool
    let color: SKColor
    let maxHP: CGFloat
    private(set) var hp: CGFloat
    private(set) var isAlive = true

    /// PV courants en fraction du maximum (0...1).
    var hpFraction: CGFloat { max(0, min(1, hp / maxHP)) }

    /// Direction de visée / orientation courante.
    var aimDirection = CGVector(dx: 0, dy: 1)

    // Buissons (SPEC §6.3) — renseignés par BushSystem.
    var revealedUntil: TimeInterval = 0
    var isHiddenInBush = false

    private let body: SKShapeNode
    private let head: SKShapeNode
    private let aimIndicator: SKShapeNode
    private let healthBG: SKSpriteNode
    private let healthFill: SKSpriteNode

    var position: CGPoint { node.position }

    init(isPlayer: Bool, color: SKColor, position: CGPoint) {
        self.isPlayer = isPlayer
        self.color = color
        self.maxHP = GameConfig.maxHP
        self.hp = GameConfig.maxHP

        let r = GameConfig.characterRadius
        node = SKNode()
        node.position = position
        node.zPosition = 10

        // Indicateur de visée (petit trait dans la direction regardée).
        aimIndicator = SKShapeNode(rectOf: CGSize(width: r * 1.2, height: 3), cornerRadius: 1.5)
        aimIndicator.fillColor = SKColor(white: 1, alpha: 0.85)
        aimIndicator.strokeColor = .clear
        aimIndicator.position = CGPoint(x: r * 0.6, y: 0)
        let aimPivot = SKNode()                 // pivot pour orienter le trait
        aimPivot.addChild(aimIndicator)
        node.addChild(aimPivot)
        self.aimPivot = aimPivot

        body = SKShapeNode(rectOf: CGSize(width: r * 0.5, height: r * 1.1), cornerRadius: r * 0.25)
        body.position = CGPoint(x: 0, y: -r * 0.4)
        body.fillColor = color
        body.strokeColor = .clear
        node.addChild(body)

        head = SKShapeNode(circleOfRadius: r * 0.45)
        head.position = CGPoint(x: 0, y: r * 0.45)
        head.fillColor = .white
        head.strokeColor = .clear
        node.addChild(head)

        // Barre de vie au-dessus de la tête.
        let barW: CGFloat = 34, barH: CGFloat = 5
        healthBG = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: CGSize(width: barW, height: barH))
        healthBG.position = CGPoint(x: 0, y: r * 1.5)
        node.addChild(healthBG)
        healthFill = SKSpriteNode(color: .green, size: CGSize(width: barW, height: barH))
        healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthFill.position = CGPoint(x: -barW / 2, y: r * 1.5)
        node.addChild(healthFill)

        let physics = SKPhysicsBody(circleOfRadius: r)
        physics.affectedByGravity = false
        physics.allowsRotation = false
        physics.linearDamping = 0
        physics.friction = 0
        physics.restitution = 0
        physics.categoryBitMask = isPlayer ? PhysicsCategory.player : PhysicsCategory.bot
        physics.collisionBitMask = PhysicsCategory.wall
        physics.contactTestBitMask = PhysicsCategory.none
        node.physicsBody = physics
    }

    private let aimPivot: SKNode

    // MARK: Déplacement

    /// Applique un vecteur d'entrée (amplitude 0...1) avec easing sur la vélocité.
    func applyMovement(_ input: CGVector) {
        guard isAlive, let physics = node.physicsBody else { return }
        let v = input.clampedToUnit()
        let target = v * GameConfig.playerSpeed
        let s = GameConfig.moveSmoothing
        physics.velocity = CGVector(
            dx: physics.velocity.dx + (target.dx - physics.velocity.dx) * s,
            dy: physics.velocity.dy + (target.dy - physics.velocity.dy) * s
        )
        if v.length > 0.05 { face(direction: v) }
    }

    func face(direction: CGVector) {
        guard direction.length > 0.001 else { return }
        aimDirection = direction.normalized()
        aimPivot.zRotation = aimDirection.angle
    }

    // MARK: Combat

    /// Inflige des dégâts. Met à jour la barre + flash. La mort est détectée
    /// par la GameScene (hp <= 0) pour centraliser le classement.
    func takeDamage(_ amount: CGFloat) {
        guard isAlive else { return }
        hp = max(0, hp - amount)
        updateHealthBar()
        flashHit()
    }

    private func updateHealthBar() {
        let ratio = max(0, hp / maxHP)
        healthFill.xScale = ratio
        healthFill.color = ratio > 0.5 ? .green : (ratio > 0.25 ? .yellow : .red)
    }

    private func flashHit() {
        let original = color
        body.run(.sequence([
            .run { [body] in body.fillColor = .white },
            .wait(forDuration: 0.06),
            .run { [body] in body.fillColor = original },
        ]))
    }

    /// Désactive le personnage (mort). Le poof visuel est géré par FX côté scène.
    func kill() {
        guard isAlive else { return }
        isAlive = false
        node.physicsBody = nil
        healthBG.isHidden = true
        healthFill.isHidden = true
        node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: Rendu buisson

    /// Applique l'alpha d'occlusion. Le joueur se voit toujours normalement.
    func applyBushAlpha(hidden: Bool) {
        isHiddenInBush = hidden
        if isPlayer {
            node.alpha = 1.0
        } else {
            node.alpha = hidden ? GameConfig.bushHiddenAlpha : 1.0
        }
    }
}
