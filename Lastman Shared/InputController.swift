//
//  InputController.swift
//  Lastman
//
//  Deux joysticks virtuels flottants → intents (SPEC §4, §9).
//  Gauche (moitié gauche de l'écran) = déplacement.
//  Droit (moitié droite) = visée + auto-fire tant qu'il est tenu.
//

import SpriteKit

final class InputController {

    let moveJoystick = Joystick()
    let aimJoystick = Joystick()

    private(set) var enabled = true

    var moveVector: CGVector { enabled ? moveJoystick.vector : .zero }
    var aimVector: CGVector { enabled ? aimJoystick.vector : .zero }
    var isFiring: Bool { enabled && aimJoystick.vector.length > 0.001 }

    func attach(to camera: SKCameraNode) {
        camera.addChild(moveJoystick)
        camera.addChild(aimJoystick)
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        if !value { moveJoystick.end(); aimJoystick.end() }
    }

    func touchesBegan(_ touches: Set<UITouch>, in camera: SKCameraNode) {
        guard enabled else { return }
        for t in touches {
            let p = t.location(in: camera)
            if p.x < 0 {
                if moveJoystick.trackedTouch == nil { moveJoystick.begin(at: p, touch: t) }
            } else {
                if aimJoystick.trackedTouch == nil { aimJoystick.begin(at: p, touch: t) }
            }
        }
    }

    func touchesMoved(_ touches: Set<UITouch>, in camera: SKCameraNode) {
        for t in touches {
            if t == moveJoystick.trackedTouch { moveJoystick.move(to: t.location(in: camera)) }
            if t == aimJoystick.trackedTouch { aimJoystick.move(to: t.location(in: camera)) }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        for t in touches {
            if t == moveJoystick.trackedTouch { moveJoystick.end() }
            if t == aimJoystick.trackedTouch { aimJoystick.end() }
        }
    }
}
