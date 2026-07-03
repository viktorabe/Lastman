//
//  ZoneSystem.swift
//  Lastman
//
//  Zone safe circulaire qui rétrécit par paliers + dégâts de poison hors-zone
//  (SPEC §6.4). Le rayon est la source de vérité, les shapes suivent.
//

import SpriteKit

final class ZoneSystem {

    private enum Phase {
        case waiting(remaining: TimeInterval)
        case shrinking(from: CGFloat, to: CGFloat, elapsed: TimeInterval)
        case done
    }

    let center: CGPoint
    private(set) var radius: CGFloat
    private let initialRadius: CGFloat
    private var nextStageIndex = 1
    private var phase: Phase

    private let border: SKShapeNode
    private let safeGround: SKShapeNode

    var isShrinking: Bool {
        if case .shrinking = phase { return true }
        return false
    }

    /// Texte pour le HUD.
    var statusText: String {
        switch phase {
        case .waiting(let remaining):
            return "Zone : \(Int(remaining.rounded(.up))) s"
        case .shrinking:
            return "⚠ LA ZONE SE FERME"
        case .done:
            return "Zone finale"
        }
    }

    init(center: CGPoint, initialRadius: CGFloat, parent: SKNode, arenaSize: CGSize) {
        self.center = center
        self.initialRadius = initialRadius
        self.radius = initialRadius * GameConfig.zoneStages[0]
        self.phase = .waiting(remaining: GameConfig.zoneShrinkInterval)

        // Voile hors-zone : teinte rouge sur toute l'arène, recouverte à
        // l'intérieur du cercle safe par un sol opaque couleur d'origine.
        // (Pas de trou dans un path : le cercle safe fait office de cache.)
        let tint = SKShapeNode(rect: CGRect(origin: .zero, size: arenaSize).insetBy(dx: -400, dy: -400))
        tint.fillColor = SKColor(red: 0.45, green: 0.08, blue: 0.12, alpha: 0.5)
        tint.strokeColor = .clear
        tint.zPosition = 0.3
        parent.addChild(tint)

        safeGround = SKShapeNode()
        safeGround.fillColor = SKColor(white: 0.09, alpha: 1)   // couleur du sol de GameScene
        safeGround.strokeColor = .clear
        safeGround.zPosition = 0.5
        parent.addChild(safeGround)

        // Bord de zone visible en permanence (cercle net).
        border = SKShapeNode()
        border.strokeColor = SKColor(red: 0.4, green: 0.75, blue: 1.0, alpha: 0.9)
        border.lineWidth = 3
        border.zPosition = 25
        border.glowWidth = 2
        parent.addChild(border)

        updateShapes()
    }

    private func updateShapes() {
        let circleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                width: radius * 2, height: radius * 2)
        border.path = CGPath(ellipseIn: circleRect, transform: nil)
        safeGround.path = CGPath(ellipseIn: circleRect, transform: nil)
    }

    // MARK: - Boucle

    func update(dt: TimeInterval, characters: [Character]) {
        switch phase {
        case .waiting(let remaining):
            let left = remaining - dt
            if left <= 0, nextStageIndex < GameConfig.zoneStages.count {
                let target = initialRadius * GameConfig.zoneStages[nextStageIndex]
                phase = .shrinking(from: radius, to: target, elapsed: 0)
                nextStageIndex += 1
            } else if left <= 0 {
                phase = .done
            } else {
                phase = .waiting(remaining: left)
            }

        case .shrinking(let from, let to, let elapsed):
            let t = elapsed + dt
            let progress = min(1, t / GameConfig.zoneShrinkDuration)
            // Ease in-out pour une fermeture douce.
            let eased = CGFloat(progress * progress * (3 - 2 * progress))
            radius = from + (to - from) * eased
            updateShapes()
            if progress >= 1 {
                radius = to
                phase = nextStageIndex < GameConfig.zoneStages.count
                    ? .waiting(remaining: GameConfig.zoneShrinkInterval)
                    : .done
            } else {
                phase = .shrinking(from: from, to: to, elapsed: t)
            }

        case .done:
            break
        }

        // Poison hors-zone, continu (SPEC : ~5 PV/s).
        for character in characters where character.isAlive {
            if isOutside(character.position) {
                character.takeDamage(GameConfig.poisonDPS * CGFloat(dt), withFX: false)
            }
        }
    }

    // MARK: - Requêtes (HUD + bots)

    func isOutside(_ point: CGPoint) -> Bool {
        point.distance(to: center) > radius
    }

    func distanceToEdge(from point: CGPoint) -> CGFloat {
        radius - point.distance(to: center)
    }

    /// Vrai si le bot doit prioriser avoidZone (SPEC §7.3).
    func isInDanger(_ point: CGPoint) -> Bool {
        if isOutside(point) { return true }
        return isShrinking && distanceToEdge(from: point) < GameConfig.zoneEdgeMargin
    }

    /// Point aléatoire confortablement dans la zone safe (pour wander).
    func randomSafePoint() -> CGPoint {
        let r = radius * CGFloat.random(in: 0.1...0.75)
        let a = CGFloat.random(in: 0...(2 * .pi))
        return CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
    }
}
