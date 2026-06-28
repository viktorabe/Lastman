//
//  ZoneSystem.swift
//  Lastman
//
//  Zone safe qui rétrécit par paliers + dégâts hors-zone (SPEC §6.4).
//

import SpriteKit

final class ZoneSystem {

    let center: CGPoint
    private(set) var currentRadius: CGFloat
    private(set) var targetRadius: CGFloat
    private let initialRadius: CGFloat

    private var stageIndex = 0
    private var nextShrink: TimeInterval = 0

    private let edge: SKShapeNode

    /// Vrai quand le rayon courant n'a pas encore atteint sa cible.
    var isShrinking: Bool { currentRadius - targetRadius > 1 }

    init(scene: SKScene, center: CGPoint) {
        self.center = center
        // Rayon initial : couvre toute l'arène (centre → coin).
        let a = GameConfig.arenaSize
        initialRadius = hypot(a.width, a.height) / 2
        currentRadius = initialRadius
        targetRadius = initialRadius

        edge = SKShapeNode(circleOfRadius: initialRadius)
        edge.position = center
        edge.fillColor = .clear
        edge.strokeColor = SKColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.9)
        edge.lineWidth = 5
        edge.zPosition = 40
        scene.addChild(edge)
    }

    func start(now: TimeInterval) {
        nextShrink = now + GameConfig.zoneShrinkInterval
    }

    func isInside(_ p: CGPoint) -> Bool { p.distance(to: center) <= currentRadius }

    /// Avance la zone et applique les dégâts de poison hors-zone.
    func update(now: TimeInterval, dt: TimeInterval, characters: [Character]) {
        // Passage au palier suivant.
        if now >= nextShrink && stageIndex < GameConfig.zoneStages.count - 1 {
            stageIndex += 1
            targetRadius = initialRadius * GameConfig.zoneStages[stageIndex]
            nextShrink = now + GameConfig.zoneShrinkInterval
        }
        // Animation du rayon vers la cible.
        if currentRadius > targetRadius {
            currentRadius = max(targetRadius, currentRadius - GameConfig.zoneShrinkRate * CGFloat(dt))
            edge.path = CGPath(ellipseIn: CGRect(x: -currentRadius, y: -currentRadius,
                                                 width: currentRadius * 2, height: currentRadius * 2),
                               transform: nil)
        }
        // Dégâts hors-zone.
        for c in characters where c.isAlive && !isInside(c.position) {
            c.takeDamage(GameConfig.poisonDPS * CGFloat(dt))
        }
    }
}
