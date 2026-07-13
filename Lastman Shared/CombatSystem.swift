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
    var damage: CGFloat = GameConfig.projectileDamage
    var range: CGFloat = GameConfig.projectileRange
}

final class CombatSystem {

    /// Couche monde où vivent les projectiles et les FX d'impact.
    private unowned let worldLayer: SKNode
    /// Screen shake, branché par GameScene.
    var onImpactShake: ((CGFloat) -> Void)?
    var onPlayerHit: ((Character) -> Void)?
    var onDamageDealt: ((Character, Character, CGFloat) -> Void)?
    var onHitStop: ((TimeInterval) -> Void)?

    private let playerWeaponStyle: WeaponStyle
    private var projectiles: [Projectile] = []

    init(worldLayer: SKNode, playerWeaponStyle: WeaponStyle) {
        self.worldLayer = worldLayer
        self.playerWeaponStyle = playerWeaponStyle
    }

    // MARK: - Boucle

    func update(dt: TimeInterval, characters: [Character], currentTime: TimeInterval) {
        // Auto-fire à cadence fixe pour quiconque a un aimIntent (joueur comme bots).
        for character in characters where character.isAlive {
            character.fireCooldown = max(0, character.fireCooldown - dt)
            if let aim = character.aimIntent, aim.length > 0.05, character.fireCooldown <= 0 {
                fire(from: character, direction: aim.normalized, currentTime: currentTime)
                character.fireCooldown = fireInterval(for: character)
            }
        }

        // Despawn au-delà de la portée max.
        projectiles.removeAll { projectile in
            guard projectile.parent != nil else { return true }
            if projectile.position.distance(to: projectile.origin) > projectile.range {
                projectile.removeFromParent()
                return true
            }
            return false
        }
    }

    func fire(from shooter: Character, direction: CGVector, currentTime: TimeInterval) {
        let dir = direction.normalized
        let radius = projectileRadius(for: shooter)
        let spawnPoint = shooter.position + dir * (GameConfig.characterRadius + radius + 7)

        if shooter.isPlayer, playerWeaponStyle.hasAimTrace {
            FX.aimTrace(from: shooter.position, to: shooter.position + dir * playerWeaponStyle.projectileRange, in: worldLayer)
        }

        let projectile = Projectile()
        projectile.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        projectile.fillColor = shooter.color
        projectile.strokeColor = .white
        projectile.lineWidth = 1
        projectile.position = spawnPoint
        projectile.zPosition = 15
        projectile.owner = shooter
        projectile.origin = spawnPoint
        projectile.damage = projectileDamage(for: shooter)
        projectile.range = projectileRange(for: shooter)
        projectile.zRotation = dir.angle

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.linearDamping = 0
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = shooter.isPlayer ? PhysicsCategory.projectilePlayer : PhysicsCategory.projectileBot
        body.collisionBitMask = PhysicsCategory.none      // pas de rebond : contact seulement
        body.contactTestBitMask = PhysicsCategory.anyCharacter | PhysicsCategory.wall | PhysicsCategory.breakable
        projectile.physicsBody = body

        worldLayer.addChild(projectile)
        body.velocity = dir * projectileSpeed(for: shooter)

        projectiles.append(projectile)
        shooter.lastShotTime = currentTime      // tirer révèle (SPEC §6.3)
        FX.muzzleFlash(at: spawnPoint,
                       angle: dir.angle,
                       in: worldLayer,
                       scale: shooter.isPlayer ? playerWeaponStyle.muzzleScale : 1)
        if shooter.isPlayer {
            FX.decoratePlayerProjectile(projectile, style: playerWeaponStyle, color: shooter.color)
            FX.shotWave(at: spawnPoint, color: shooter.color, style: playerWeaponStyle, in: worldLayer)
            Haptics.playerShot(style: playerWeaponStyle)
            onImpactShake?(playerWeaponStyle.shotShake)
            if playerWeaponStyle.recoilImpulse > 0 {
                shooter.applyImpulse(dir * -playerWeaponStyle.recoilImpulse)
            }
        }
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
                      let target = characterNode.character,
                      target.isAlive else { return }
                // Un projectile ne touche pas son tireur (SPEC §6.2).
                if target === projectile.owner { return }

                FX.impactSparks(at: projectile.position, color: .white, in: worldLayer)
                projectile.removeFromParent()
                onImpactShake?(3)
                if target.isPlayer {
                    Haptics.playerDamaged()
                } else if projectile.owner?.isPlayer == true {
                    Haptics.hitLanded()
                }
                let beforeHP = target.hp
                let didDamage = target.takeDamage(projectile.damage, source: projectile.owner)
                let actualDamage = max(0, beforeHP - target.hp)
                if didDamage, let owner = projectile.owner {
                    onDamageDealt?(owner, target, actualDamage)
                    if owner.isPlayer {
                        FX.damageNumber(actualDamage, at: target.position, color: owner.color, in: worldLayer)
                        if target.isAlive {
                            onHitStop?(GameConfig.hitStopDuration)
                        }
                    }
                }
                if didDamage, projectile.owner?.isPlayer == true, target.isAlive {
                    onPlayerHit?(target)
                }
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

    private func projectileRadius(for shooter: Character) -> CGFloat {
        shooter.isPlayer ? playerWeaponStyle.projectileRadius : 3
    }

    private func projectileDamage(for shooter: Character) -> CGFloat {
        shooter.isPlayer ? playerWeaponStyle.projectileDamage : GameConfig.projectileDamage
    }

    private func projectileSpeed(for shooter: Character) -> CGFloat {
        shooter.isPlayer ? playerWeaponStyle.projectileSpeed : GameConfig.projectileSpeed
    }

    private func projectileRange(for shooter: Character) -> CGFloat {
        shooter.isPlayer ? playerWeaponStyle.projectileRange : GameConfig.projectileRange
    }

    private func fireInterval(for shooter: Character) -> TimeInterval {
        shooter.isPlayer ? playerWeaponStyle.fireInterval : GameConfig.fireInterval
    }
}
