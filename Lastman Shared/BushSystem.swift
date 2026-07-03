//
//  BushSystem.swift
//  Lastman
//
//  Buissons : occlusion et révélation (SPEC §6.3). Pas de collision physique,
//  détection géométrique de chevauchement (ellipses).
//

import SpriteKit

struct Bush {
    let id: Int
    let center: CGPoint
    let radii: CGSize      // demi-axes de l'ellipse

    func contains(_ point: CGPoint) -> Bool {
        let dx = (point.x - center.x) / radii.width
        let dy = (point.y - center.y) / radii.height
        return dx * dx + dy * dy <= 1
    }
}

final class BushSystem {

    private(set) var bushes: [Bush] = []

    init(layout: [(center: CGPoint, radii: CGSize)], parent: SKNode) {
        for (index, spec) in layout.enumerated() {
            bushes.append(Bush(id: index, center: spec.center, radii: spec.radii))
            parent.addChild(makeBushNode(center: spec.center, radii: spec.radii))
        }
    }

    /// Formes douces semi-transparentes, dessinées AU-DESSUS des personnages
    /// pour que quelqu'un dedans apparaisse sous le feuillage.
    private func makeBushNode(center: CGPoint, radii: CGSize) -> SKNode {
        let container = SKNode()
        container.position = center
        container.zPosition = 20

        let outer = SKShapeNode(ellipseOf: CGSize(width: radii.width * 2, height: radii.height * 2))
        outer.fillColor = SKColor(white: 1, alpha: 0.10)
        outer.strokeColor = SKColor(white: 1, alpha: 0.30)
        outer.lineWidth = 1.5

        let inner = SKShapeNode(ellipseOf: CGSize(width: radii.width * 1.2, height: radii.height * 1.2))
        inner.fillColor = SKColor(white: 1, alpha: 0.07)
        inner.strokeColor = SKColor(white: 1, alpha: 0.15)
        inner.lineWidth = 1

        container.addChild(outer)
        container.addChild(inner)
        return container
    }

    func bushID(at point: CGPoint) -> Int? {
        bushes.first { $0.contains(point) }?.id
    }

    func nearestBush(to point: CGPoint) -> Bush? {
        bushes.min { $0.center.distance(to: point) < $1.center.distance(to: point) }
    }

    // MARK: - Boucle

    func update(characters: [Character], currentTime: TimeInterval) {
        let alive = characters.filter { $0.isAlive }

        for character in alive {
            character.currentBushID = bushID(at: character.position)
        }

        for character in alive {
            guard character.currentBushID != nil else {
                character.isRevealed = true
                continue
            }
            // Révélé s'il a tiré récemment…
            var revealed = (currentTime - character.lastShotTime) < GameConfig.bushRevealAfterShot
            // …ou si un ennemi est dans le même buisson / trop proche (SPEC §6.3).
            if !revealed {
                for other in alive where other !== character {
                    if other.currentBushID == character.currentBushID
                        || other.position.distance(to: character.position) < GameConfig.bushRevealDistance {
                        revealed = true
                        break
                    }
                }
            }
            character.isRevealed = revealed
        }

        for character in alive {
            character.updateConcealmentVisual()
        }
    }

    /// Perception bot : une cible cachée non révélée n'existe pas (SPEC §7.1).
    func canPerceive(_ target: Character) -> Bool {
        !target.isConcealed
    }
}
