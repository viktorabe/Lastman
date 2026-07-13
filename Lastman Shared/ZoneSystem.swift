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
    private let previewBorder: SKShapeNode
    private let safeGround: SKShapeNode
    private var pressureMultiplier: CGFloat = 1

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

    init(
        center: CGPoint,
        initialRadius: CGFloat,
        parent: SKNode,
        arenaSize: CGSize,
        initialPressureMultiplier: CGFloat = 1
    ) {
        self.center = center
        self.initialRadius = initialRadius
        self.radius = initialRadius * GameConfig.zoneStages[0]
        self.phase = .waiting(remaining: GameConfig.zoneShrinkInterval)
        self.pressureMultiplier = initialPressureMultiplier

        // Voile hors-zone : teinte rouge sur toute l'arène, recouverte à
        // l'intérieur du cercle safe par un sol opaque couleur d'origine.
        // (Pas de trou dans un path : le cercle safe fait office de cache.)
        let tint = SKShapeNode(rect: CGRect(origin: .zero, size: arenaSize).insetBy(dx: -400, dy: -400))
        tint.fillColor = SKColor(red: 0.45, green: 0.08, blue: 0.12, alpha: 0.5)
        tint.strokeColor = .clear
        tint.zPosition = 0.3
        parent.addChild(tint)

        safeGround = SKShapeNode()
        safeGround.fillColor = SKColor(red: 0.075, green: 0.085, blue: 0.095, alpha: 1)   // couleur du sol de GameScene
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

        // Prochain cercle : lisible mais discret, pour anticiper la rotation.
        previewBorder = SKShapeNode()
        previewBorder.strokeColor = SKColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 0.34)
        previewBorder.lineWidth = 2
        previewBorder.lineCap = .round
        previewBorder.zPosition = 24
        previewBorder.glowWidth = 1
        parent.addChild(previewBorder)

        updateShapes()
    }

    private func updateShapes() {
        let circleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                width: radius * 2, height: radius * 2)
        border.path = CGPath(ellipseIn: circleRect, transform: nil)
        safeGround.path = CGPath(ellipseIn: circleRect, transform: nil)
        updatePreviewShape()
    }

    private func updatePreviewShape() {
        guard nextStageIndex < GameConfig.zoneStages.count else {
            previewBorder.path = nil
            return
        }

        let previewRadius = initialRadius * GameConfig.zoneStages[nextStageIndex]
        previewBorder.path = dashedCirclePath(center: center, radius: previewRadius)
        previewBorder.alpha = isShrinking ? 0.16 : 1
    }

    private func dashedCirclePath(center: CGPoint, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let dashCount = max(18, Int(radius / 18))
        let step = (2 * CGFloat.pi) / CGFloat(dashCount)
        let dashLength = step * 0.56

        for index in 0..<dashCount {
            let start = CGFloat(index) * step
            let startPoint = CGPoint(x: center.x + cos(start) * radius,
                                     y: center.y + sin(start) * radius)
            path.move(to: startPoint)
            path.addArc(center: center,
                        radius: radius,
                        startAngle: start,
                        endAngle: start + dashLength,
                        clockwise: false)
        }

        return path
    }

    // MARK: - Boucle

    func update(dt: TimeInterval, characters: [Character]) {
        let adjustedDT = dt / TimeInterval(pressureMultiplier)
        switch phase {
        case .waiting(let remaining):
            let left = remaining - adjustedDT
            if left <= 0, nextStageIndex < GameConfig.zoneStages.count {
                let target = initialRadius * GameConfig.zoneStages[nextStageIndex]
                phase = .shrinking(from: radius, to: target, elapsed: 0)
                nextStageIndex += 1
                updatePreviewShape()
            } else if left <= 0 {
                phase = .done
                updatePreviewShape()
            } else {
                phase = .waiting(remaining: left)
            }

        case .shrinking(let from, let to, let elapsed):
            let t = elapsed + adjustedDT
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
                updatePreviewShape()
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

    func intensifyFinale() {
        guard pressureMultiplier > GameConfig.topThreeZoneShrinkMultiplier else { return }
        pressureMultiplier = GameConfig.topThreeZoneShrinkMultiplier
        if case .waiting(let remaining) = phase {
            phase = .waiting(remaining: max(3, remaining * TimeInterval(GameConfig.topThreeZoneShrinkMultiplier)))
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

    /// Point de patrouille déterministe dans la zone safe.
    func patrolPoint(index: Int) -> CGPoint {
        let normalizedIndex = ((index % 12) + 12) % 12
        let r = radius * (normalizedIndex.isMultiple(of: 2) ? 0.38 : 0.52)
        let a = CGFloat(normalizedIndex) * (2 * .pi / 12)
        return CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
    }
}
