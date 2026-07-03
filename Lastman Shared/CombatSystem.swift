//
//  CombatSystem.swift
//  Lastman
//
//  Tir auto, projectiles physiques, dégâts (SPEC §6.2).
//

import SpriteKit

/// Projectile physique : porte son tireur (immunité) et son point d'origine (portée max).
final class Projectile: SKShapeNode {
    weak var owner: Character?
    var origin: CGPoint = .zero
}

final class CombatSystem {

    /// Couche monde où vivent les projectiles et les FX d'impact.
    private unowned let worldLayer: SKNode
    /// Screen shake, branché par GameScene.
    var onImpactShake: ((CGFloat) -> Void)?

    private var projectiles: [Projectile] = []

    init(worldLayer: SKNode) {
        self.worldLayer = worldLayer
    }

    // MARK: - Boucle

    func update(dt: TimeInterval, characters: [Character], currentTime: TimeInterval) {
        // Auto-fire à cadence fixe pour quiconque a un aimIntent (joueur comme bots).
        for character in characters where character.isAlive {
            character.fireCooldown = max(0, character.fireCooldown - dt)
            if let aim = character.aimIntent, aim.length > 0.05, character.fireCooldown <= 0 {
                fire(from: character, direction: aim.normalized, currentTime: currentTime)
                character.fireCooldown = GameConfig.fireInterval
            }
        }

        // Despawn au-delà de la portée max.
        projectiles.removeAll { projectile in
            guard projectile.parent != nil else { return true }
            if projectile.position.distance(to: projectile.origin) > GameConfig.projectileRange {
                projectile.removeFromParent()
                return true
            }
            return false
        }
    }

    func fire(from shooter: Character, direction: CGVector, currentTime: TimeInterval) {
        let dir = direction.normalized
        let spawnPoint = shooter.position + dir * (GameConfig.characterRadius + 10)

        let projectile = Projectile()
        projectile.path = CGPath(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6), transform: nil)
        projectile.fillColor = shooter.color
        projectile.strokeColor = .white
        projectile.lineWidth = 1
        projectile.position = spawnPoint
        projectile.zPosition = 15
        projectile.owner = shooter
        projectile.origin = spawnPoint

        let body = SKPhysicsBody(circleOfRadius: 3)
        body.affectedByGravity = false
        body.linearDamping = 0
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = shooter.isPlayer ? PhysicsCategory.projectilePlayer : PhysicsCategory.projectileBot
        body.collisionBitMask = PhysicsCategory.none      // pas de rebond : contact seulement
        body.contactTestBitMask = PhysicsCategory.anyCharacter | PhysicsCategory.wall
        projectile.physicsBody = body

        worldLayer.addChild(projectile)
        body.velocity = dir * GameConfig.projectileSpeed

        projectiles.append(projectile)
        shooter.lastShotTime = currentTime      // tirer révèle (SPEC §6.3)
        FX.muzzleFlash(at: spawnPoint, angle: dir.angle, in: worldLayer)
    }

    // MARK: - Contacts physiques (appelé par GameScene.didBegin)

    func handleContact(_ contact: SKPhysicsContact) {
        let pairs = [(contact.bodyA, contact.bodyB), (contact.bodyB, contact.bodyA)]
        for (first, second) in pairs {
            guard first.categoryBitMask & PhysicsCategory.anyProjectile != 0,
                  let projectile = first.node as? Projectile,
                  projectile.parent != nil else { continue }

            if second.categoryBitMask & PhysicsCategory.anyCharacter != 0 {
                guard let characterNode = second.node as? CharacterNode,
                      let target = characterNode.entity,
                      target.isAlive else { return }
                // Un projectile ne touche pas son tireur (SPEC §6.2).
                if target === projectile.owner { return }

                FX.impactSparks(at: projectile.position, color: .white, in: worldLayer)
                projectile.removeFromParent()
                onImpactShake?(3)
                target.takeDamage(GameConfig.projectileDamage)
            } else if second.categoryBitMask & PhysicsCategory.wall != 0 {
                FX.impactSparks(at: projectile.position, color: SKColor(white: 1, alpha: 0.6), in: worldLayer, count: 5)
                projectile.removeFromParent()
            }
            return
        }
    }

    func removeAllProjectiles() {
        for projectile in projectiles {
            projectile.removeFromParent()
        }
        projectiles.removeAll()
    }
}
