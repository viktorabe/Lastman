//
//  BreakableSystem.swift
//  Lastman
//
//  Objets destructibles qui ajoutent des micro-objectifs : soin, boost et
//  explosif. Les bots peuvent lire les objectifs de soin sans posséder les nodes.
//

import SpriteKit

enum BreakableKind: CaseIterable {
    case heal
    case speed
    case shield
    case explosive

    var crateColor: SKColor {
        switch self {
        case .heal: return SKColor(red: 0.18, green: 0.95, blue: 0.58, alpha: 1)
        case .speed: return SKColor(red: 0.36, green: 0.62, blue: 1.0, alpha: 1)
        case .shield: return SKColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 1)
        case .explosive: return SKColor(red: 1.0, green: 0.28, blue: 0.22, alpha: 1)
        }
    }

    var symbol: String {
        switch self {
        case .heal: return "+"
        case .speed: return ">"
        case .shield: return "O"
        case .explosive: return "!"
        }
    }
}

enum PickupKind {
    case heal
    case speed
    case shield

    var color: SKColor {
        switch self {
        case .heal: return SKColor(red: 0.52, green: 1.0, blue: 0.76, alpha: 1)
        case .speed: return SKColor(red: 0.45, green: 0.72, blue: 1.0, alpha: 1)
        case .shield: return SKColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 1)
        }
    }

    var symbol: String {
        switch self {
        case .heal: return "+"
        case .speed: return ">"
        case .shield: return "O"
        }
    }
}

struct HealingObjective {
    enum Source {
        case pickup
        case breakable
    }

    let position: CGPoint
    let source: Source
}

final class BreakableNode: SKNode {
    let kind: BreakableKind
    var hp: CGFloat = GameConfig.breakableHP

    init(kind: BreakableKind) {
        self.kind = kind
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class PickupNode: SKNode {
    let kind: PickupKind

    init(kind: PickupKind) {
        self.kind = kind
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class BreakableSystem {

    private unowned let worldLayer: SKNode
    private let arenaRect: CGRect
    private let blockedAreas: [(center: CGPoint, radius: CGFloat)]
    private var breakables: [BreakableNode] = []
    private var pickups: [PickupNode] = []
    private var nextSpawnTime: TimeInterval = 0
    var onPlayerPickupCollected: (() -> Void)?
    var onPlayerBreakableDestroyed: (() -> Void)?
    var onDamageDealt: ((Character, Character, CGFloat) -> Void)?

    init(worldLayer: SKNode, arenaRect: CGRect, blockedAreas: [(center: CGPoint, radius: CGFloat)]) {
        self.worldLayer = worldLayer
        self.arenaRect = arenaRect
        self.blockedAreas = blockedAreas
    }

    func spawnInitial(characters: [Character]) {
        for _ in 0..<GameConfig.maxBreakables {
            spawnBreakableIfPossible(near: characters)
        }
    }

    func update(currentTime: TimeInterval, characters: [Character]) {
        breakables.removeAll { $0.parent == nil }
        pickups.removeAll { $0.parent == nil }

        guard currentTime >= nextSpawnTime else { return }
        if breakables.count < GameConfig.maxBreakables {
            spawnBreakableIfPossible(near: characters)
            nextSpawnTime = currentTime + GameConfig.breakableRespawnInterval
        }
    }

    func handleContact(_ contact: SKPhysicsContact, characters: [Character]) -> Bool {
        if handleProjectileImpact(contact, characters: characters) { return true }
        if handlePickup(contact) { return true }
        return false
    }

    func nearestHealingObjective(to point: CGPoint, maxDistance: CGFloat) -> HealingObjective? {
        let healPickups = pickups.filter { $0.parent != nil && $0.kind == .heal }
        if let pickup = healPickups.min(by: { $0.position.distance(to: point) < $1.position.distance(to: point) }),
           pickup.position.distance(to: point) <= maxDistance {
            return HealingObjective(position: pickup.position, source: .pickup)
        }

        let healBreakables = breakables.filter { $0.parent != nil && $0.kind == .heal }
        if let breakable = healBreakables.min(by: { $0.position.distance(to: point) < $1.position.distance(to: point) }),
           breakable.position.distance(to: point) <= maxDistance {
            return HealingObjective(position: breakable.position, source: .breakable)
        }

        return nil
    }

    private func handleProjectileImpact(_ contact: SKPhysicsContact, characters: [Character]) -> Bool {
        let pairs = [(contact.bodyA, contact.bodyB), (contact.bodyB, contact.bodyA)]
        for (first, second) in pairs {
            guard first.categoryBitMask & PhysicsCategory.anyProjectile != 0,
                  let projectile = first.node as? Projectile,
                  projectile.parent != nil,
                  second.categoryBitMask & PhysicsCategory.breakable != 0,
                  let breakable = second.node as? BreakableNode,
                  breakable.parent != nil else { continue }

            let owner = projectile.owner
            projectile.removeFromParent()
            damage(breakable,
                   amount: projectile.damage,
                   impactPoint: projectile.position,
                   characters: characters,
                   owner: owner)
            return true
        }
        return false
    }

    private func handlePickup(_ contact: SKPhysicsContact) -> Bool {
        let pairs = [(contact.bodyA, contact.bodyB), (contact.bodyB, contact.bodyA)]
        for (first, second) in pairs {
            guard first.categoryBitMask & PhysicsCategory.healPickup != 0,
                  let pickup = first.node as? PickupNode,
                  pickup.parent != nil,
                  second.categoryBitMask & PhysicsCategory.anyCharacter != 0,
                  let characterNode = second.node as? CharacterNode,
                  let character = characterNode.character,
                  character.isAlive else { continue }

            let wasUsed: Bool
            switch pickup.kind {
            case .heal:
                wasUsed = character.heal(GameConfig.healAmount)
            case .speed:
                character.applySpeedBoost(duration: GameConfig.speedBoostDuration)
                wasUsed = true
            case .shield:
                character.applyShield(duration: GameConfig.shieldDuration)
                wasUsed = true
            }

            if wasUsed {
                collect(pickup, by: character)
                if character.isPlayer {
                    onPlayerPickupCollected?()
                }
            }
            return true
        }
        return false
    }

    private func spawnBreakableIfPossible(near characters: [Character]) {
        guard let point = randomSpawnPoint(avoiding: characters) else { return }
        let breakable = makeBreakable(kind: randomKind())
        breakable.position = point
        breakables.append(breakable)
        worldLayer.addChild(breakable)

        let ring = SKShapeNode(circleOfRadius: GameConfig.breakableRadius + 8)
        ring.strokeColor = breakable.kind.crateColor.withAlphaComponent(0.65)
        ring.fillColor = .clear
        ring.lineWidth = 1.5
        ring.zPosition = -1
        breakable.addChild(ring)

        breakable.setScale(0.25)
        breakable.alpha = 0
        breakable.run(.group([
            .scale(to: 1, duration: 0.18),
            .fadeIn(withDuration: 0.18),
        ]))
        ring.run(.sequence([
            .group([
                .scale(to: 1.9, duration: 0.28),
                .fadeOut(withDuration: 0.28),
            ]),
            .removeFromParent(),
        ]))
    }

    private func randomKind() -> BreakableKind {
        let roll = CGFloat.random(in: 0...1)
        if roll < 0.42 { return .heal }
        if roll < 0.68 { return .speed }
        if roll < 0.88 { return .shield }
        return .explosive
    }

    private func randomSpawnPoint(avoiding characters: [Character]) -> CGPoint? {
        let inset = arenaRect.insetBy(dx: GameConfig.breakableSpawnInset,
                                      dy: GameConfig.breakableSpawnInset)
        for _ in 0..<40 {
            let point = CGPoint(x: CGFloat.random(in: inset.minX...inset.maxX),
                                y: CGFloat.random(in: inset.minY...inset.maxY))
            if isSpawnPointClear(point, characters: characters) {
                return point
            }
        }
        return nil
    }

    private func isSpawnPointClear(_ point: CGPoint, characters: [Character]) -> Bool {
        for character in characters where character.isAlive {
            if point.distance(to: character.position) < GameConfig.breakableMinDistanceFromCharacter {
                return false
            }
        }

        for breakable in breakables where breakable.parent != nil {
            if point.distance(to: breakable.position) < GameConfig.breakableMinDistanceFromObject {
                return false
            }
        }

        for blocked in blockedAreas {
            let minDistance = blocked.radius + GameConfig.breakableRadius + 18
            if point.distance(to: blocked.center) < minDistance {
                return false
            }
        }

        return true
    }

    private func makeBreakable(kind: BreakableKind) -> BreakableNode {
        let node = BreakableNode(kind: kind)
        node.zPosition = 4

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 42, height: 14))
        shadow.position = CGPoint(x: 0, y: -16)
        shadow.fillColor = SKColor(white: 0, alpha: 0.22)
        shadow.strokeColor = .clear
        node.addChild(shadow)

        let crate = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 5)
        crate.fillColor = SKColor(red: 0.24, green: 0.23, blue: 0.21, alpha: 1)
        crate.strokeColor = kind.crateColor
        crate.lineWidth = 2.5
        node.addChild(crate)

        let symbol = makeLabel(kind.symbol, size: 18, color: kind.crateColor, font: UIFont2.heavy)
        symbol.position = CGPoint(x: 0, y: 1)
        node.addChild(symbol)

        let body = SKPhysicsBody(circleOfRadius: GameConfig.breakableRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.breakable
        body.collisionBitMask = PhysicsCategory.anyCharacter
        body.contactTestBitMask = PhysicsCategory.anyProjectile
        body.friction = 0
        node.physicsBody = body
        return node
    }

    private func damage(_ breakable: BreakableNode,
                        amount: CGFloat,
                        impactPoint: CGPoint,
                        characters: [Character],
                        owner: Character?) {
        breakable.hp = max(0, breakable.hp - amount)
        FX.impactSparks(at: impactPoint, color: breakable.kind.crateColor, in: worldLayer, count: 7)
        breakable.run(.sequence([
            .scale(to: 1.08, duration: 0.04),
            .scale(to: 1, duration: 0.08),
        ]))

        if breakable.hp <= 0 {
            shatter(breakable, characters: characters, owner: owner)
        }
    }

    private func shatter(_ breakable: BreakableNode, characters: [Character], owner: Character?) {
        let point = breakable.position
        let kind = breakable.kind
        breakable.removeFromParent()
        FX.impactSparks(at: point, color: kind.crateColor, in: worldLayer, count: kind == .explosive ? 30 : 18)
        if owner?.isPlayer == true {
            onPlayerBreakableDestroyed?()
        }

        switch kind {
        case .heal:
            spawnPickup(kind: .heal, at: point)
        case .speed:
            spawnPickup(kind: .speed, at: point)
        case .shield:
            spawnPickup(kind: .shield, at: point)
        case .explosive:
            explode(at: point, characters: characters, owner: owner)
        }
    }

    private func spawnPickup(kind: PickupKind, at point: CGPoint) {
        let pickup = PickupNode(kind: kind)
        pickup.position = point
        pickup.zPosition = 6

        let ring = SKShapeNode(circleOfRadius: GameConfig.pickupRadius)
        ring.fillColor = kind.color.withAlphaComponent(0.22)
        ring.strokeColor = kind.color
        ring.lineWidth = 2
        pickup.addChild(ring)

        let label = makeLabel(kind.symbol, size: 16, color: kind.color, font: UIFont2.heavy)
        label.position = CGPoint(x: 0, y: 1)
        pickup.addChild(label)

        let body = SKPhysicsBody(circleOfRadius: GameConfig.pickupRadius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.healPickup
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.anyCharacter
        pickup.physicsBody = body

        pickups.append(pickup)
        worldLayer.addChild(pickup)
        pickup.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.45),
            .scale(to: 1.0, duration: 0.45),
        ])), withKey: "pulse")
    }

    private func explode(at point: CGPoint, characters: [Character], owner: Character?) {
        let ring = SKShapeNode(circleOfRadius: GameConfig.explosiveRadius)
        ring.position = point
        ring.strokeColor = SKColor(red: 1, green: 0.32, blue: 0.22, alpha: 0.9)
        ring.fillColor = SKColor(red: 1, green: 0.18, blue: 0.08, alpha: 0.12)
        ring.lineWidth = 3
        ring.zPosition = 28
        worldLayer.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 1.25, duration: 0.18),
                .fadeOut(withDuration: 0.18),
            ]),
            .removeFromParent(),
        ]))

        for character in characters where character.isAlive {
            let distance = character.position.distance(to: point)
            guard distance <= GameConfig.explosiveRadius else { continue }
            let falloff = max(0.35, 1 - distance / GameConfig.explosiveRadius)
            let beforeHP = character.hp
            let didDamage = character.takeDamage(GameConfig.explosiveDamage * falloff, source: owner)
            let actualDamage = max(0, beforeHP - character.hp)
            if didDamage, let owner {
                onDamageDealt?(owner, character, actualDamage)
            }
        }
    }

    private func collect(_ pickup: PickupNode, by character: Character) {
        let point = pickup.position
        let color = pickup.kind.color
        pickup.physicsBody = nil
        pickup.removeFromParent()

        FX.impactSparks(at: point, color: color, in: worldLayer, count: 14)
        if character.isPlayer {
            Haptics.hitLanded()
        }
    }
}
