//
//  Joystick.swift
//  Lastman
//
//  Joystick virtuel flottant : apparaît là où le pouce se pose (SPEC §4).
//

import SpriteKit

final class VirtualJoystick: SKNode {

    /// Vecteur de sortie, amplitude 0...1.
    private(set) var value: CGVector = .zero

    private let base: SKShapeNode
    private let knob: SKShapeNode
    private let radius: CGFloat = 52

    override init() {
        base = SKShapeNode(circleOfRadius: radius)
        base.strokeColor = SKColor(white: 1, alpha: 0.3)
        base.lineWidth = 2
        base.fillColor = SKColor(white: 1, alpha: 0.05)

        knob = SKShapeNode(circleOfRadius: 22)
        knob.strokeColor = .clear
        knob.fillColor = SKColor(white: 1, alpha: 0.35)

        super.init()
        addChild(base)
        addChild(knob)
        alpha = 0
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `point` en coordonnées du parent.
    func activate(at point: CGPoint) {
        removeAllActions()
        position = point
        knob.position = .zero
        value = .zero
        run(.fadeAlpha(to: 1, duration: 0.08))
    }

    func move(to point: CGPoint) {
        var offset = CGVector(from: position, to: point)
        let l = offset.length
        if l > radius {
            offset = offset.normalized * radius
        }
        knob.position = CGPoint(x: offset.dx, y: offset.dy)
        value = CGVector(dx: offset.dx / radius, dy: offset.dy / radius)
    }

    func deactivate() {
        value = .zero
        knob.position = .zero
        run(.fadeOut(withDuration: 0.12))
    }
}
