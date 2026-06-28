//
//  BushSystem.swift
//  Lastman
//
//  Occlusion / révélation des buissons (SPEC §6.3). Détection géométrique
//  simple (cercles statiques) — pas de physics sensor nécessaire.
//

import SpriteKit

final class BushSystem {

    private struct Bush { let center: CGPoint; let radius: CGFloat }
    private var bushes: [Bush] = []

    /// Place les buissons dans la scène et mémorise leur géométrie.
    func build(in scene: SKScene, layout: [(CGPoint, CGFloat)]) {
        for (center, radius) in layout {
            bushes.append(Bush(center: center, radius: radius))
            let node = SKShapeNode(circleOfRadius: radius)
            node.position = center
            node.fillColor = SKColor(red: 0.25, green: 0.5, blue: 0.3, alpha: 0.35)
            node.strokeColor = SKColor(red: 0.4, green: 0.7, blue: 0.45, alpha: 0.4)
            node.lineWidth = 2
            node.zPosition = 50          // au-dessus des persos pour l'effet de couvert
            scene.addChild(node)
        }
    }

    private func bushIndex(at p: CGPoint) -> Int? {
        bushes.firstIndex { p.distance(to: $0.center) < $0.radius }
    }

    /// Recalcule, pour chaque personnage vivant, son état caché/révélé + alpha.
    /// À appeler avant la perception des bots.
    func update(characters: [Character], now: TimeInterval) {
        for c in characters where c.isAlive {
            guard let bi = bushIndex(at: c.position) else {
                c.applyBushAlpha(hidden: false)
                continue
            }
            // Révélé s'il a tiré récemment, ou si un ennemi est dans le même
            // buisson / sous la distance seuil.
            var revealed = now < c.revealedUntil
            if !revealed {
                for other in characters where other !== c && other.isAlive {
                    let close = other.position.distance(to: c.position) < GameConfig.bushRevealDistance
                    let sameBush = bushIndex(at: other.position) == bi
                    if close || sameBush { revealed = true; break }
                }
            }
            c.applyBushAlpha(hidden: !revealed)
        }
    }
}
