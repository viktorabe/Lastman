//
//  CombatSystem.swift
//  Lastman
//
//  Tir auto à cadence fixe + projectiles physiques (SPEC §6.2). La résolution
//  des contacts (dégâts/despawn) est faite par GameScene.didBegin.
//

import SpriteKit

final class CombatSystem {

    private unowned let scene: SKScene
    private var lastFire: [ObjectIdentifier: TimeInterval] = [:]

    init(scene: SKScene) { self.scene = scene }

    /// Tente de tirer depuis `shooter` vers `direction`, en respectant la cadence.
    func tryFire(from shooter: Character, direction: CGVector, now: TimeInterval) {
        guard shooter.isAlive, direction.length > 0.001 else { return }
        let id = ObjectIdentifier(shooter)
        if now - (lastFire[id] ?? -999) < GameConfig.fireInterval { return }
        lastFire[id] = now

        spawnProjectile(from: shooter, direction: direction.normalized())
        shooter.revealedUntil = now + GameConfig.bushRevealDuration   // tirer révèle (SPEC §6.3)
        FX.muzzleFlash(at: muzzlePoint(of: shooter, direction: direction), in: scene)
    }

    private func muzzlePoint(of shooter: Character, direction: CGVector) -> CGPoint {
        shooter.position + direction.normalized() * (GameConfig.characterRadius + 6)
    }

    private func spawnProjectile(from shooter: Character, direction: CGVector) {
        let r = GameConfig.projectileRadius
        let proj = SKShapeNode(circleOfRadius: r)
        proj.fillColor = shooter.isPlayer ? Player.signature : .white
        proj.strokeColor = .clear
        proj.position = muzzlePoint(of: shooter, direction: direction)
        proj.zPosition = 8
        proj.name = "projectile"

        let body = SKPhysicsBody(circleOfRadius: r)
        body.affectedByGravity = false
        body.linearDamping = 0
        body.categoryBitMask = shooter.isPlayer ? PhysicsCategory.projectilePlayer : PhysicsCategory.projectileBot
        // Le projectile traverse logiquement mais notifie le contact (pas de rebond).
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = (shooter.isPlayer ? PhysicsCategory.bot : PhysicsCategory.player) | PhysicsCategory.wall
        body.velocity = direction * GameConfig.projectileSpeed
        proj.physicsBody = body

        scene.addChild(proj)

        // Despawn au bout de la portée max (SPEC §6.2).
        let life = TimeInterval(GameConfig.projectileRange / GameConfig.projectileSpeed)
        proj.run(.sequence([.wait(forDuration: life), .removeFromParent()]))
    }
}
