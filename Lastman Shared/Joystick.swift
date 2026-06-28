//
//  Joystick.swift
//  Lastman
//
//  Joystick virtuel flottant (SPEC §4) : analogique, 360°, vitesse
//  proportionnelle à l'amplitude. Le node est attaché à la caméra et déplacé
//  là où le pouce se pose. `vector` renvoie un déplacement normalisé clampé à 1.
//

import SpriteKit

final class Joystick: SKNode {

    private let base: SKShapeNode
    private let knob: SKShapeNode
    private let radius: CGFloat

    /// Vecteur de sortie : direction du pouce, amplitude dans [0, 1].
    /// Zéro si le joystick est inactif ou dans la zone morte.
    private(set) var vector: CGVector = .zero

    /// Touch actuellement suivi par ce joystick (nil si inactif).
    private(set) var trackedTouch: UITouch?

    init(radius: CGFloat = GameConfig.joystickRadius) {
        self.radius = radius
        base = SKShapeNode(circleOfRadius: radius)
        knob = SKShapeNode(circleOfRadius: radius * 0.45)
        super.init()

        base.strokeColor = SKColor(white: 1, alpha: 0.35)
        base.fillColor = SKColor(white: 1, alpha: 0.06)
        base.lineWidth = 3
        addChild(base)

        knob.strokeColor = SKColor(white: 1, alpha: 0.6)
        knob.fillColor = SKColor(white: 1, alpha: 0.2)
        knob.lineWidth = 2
        addChild(knob)

        zPosition = 1000
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Pose le joystick à l'endroit du toucher (coordonnées de la caméra/parent).
    func begin(at point: CGPoint, touch: UITouch) {
        trackedTouch = touch
        position = point
        knob.position = .zero
        vector = .zero
        isHidden = false
    }

    /// Met à jour la position du knob et recalcule le vecteur de sortie.
    func move(to point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let dist = max(hypot(dx, dy), 0.0001)
        let clamped = min(dist, radius)

        // Position visuelle du knob, bornée au rayon de la base.
        knob.position = CGPoint(x: dx / dist * clamped, y: dy / dist * clamped)

        let amplitude = clamped / radius
        if amplitude < GameConfig.joystickDeadZone {
            vector = .zero
        } else {
            vector = CGVector(dx: dx / dist * amplitude, dy: dy / dist * amplitude)
        }
    }

    /// Relâche le joystick : sortie remise à zéro, node masqué.
    func end() {
        trackedTouch = nil
        vector = .zero
        knob.position = .zero
        isHidden = true
    }
}
