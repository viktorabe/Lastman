//
//  InputController.swift
//  Lastman
//
//  Deux joysticks flottants → intents (move vec, aim vec). SPEC §4 :
//  gauche = déplacement analogique, droit = visée + auto-fire tant que tenu.
//

import SpriteKit

final class InputController {

    let moveStick = VirtualJoystick()
    let aimStick = VirtualJoystick()

    /// Bloqué pendant le countdown (SPEC §5).
    var isEnabled = false {
        didSet {
            if !isEnabled {
                releaseAll()
            }
        }
    }

    /// Couche HUD (enfant de la caméra) dans laquelle vivent les joysticks.
    private unowned let hud: SKNode
    private var screenSize: CGSize

    private var moveTouch: UITouch?
    private var aimTouch: UITouch?

    var moveVector: CGVector { moveStick.value }
    var aimVector: CGVector { aimStick.value.normalized }
    /// Le joystick droit tenu et poussé = auto-fire (pas de bouton séparé).
    var isAiming: Bool { aimTouch != nil && aimStick.value.length > 0.2 }

    init(hud: SKNode, screenSize: CGSize) {
        self.hud = hud
        self.screenSize = screenSize
        moveStick.zPosition = 100
        aimStick.zPosition = 100
        hud.addChild(moveStick)
        hud.addChild(aimStick)
    }

    func updateScreenSize(_ screenSize: CGSize) {
        self.screenSize = screenSize
        releaseAll()
    }

    // MARK: - Touches (transmis par GameScene ; coordonnées HUD, origine au centre de l'écran)

    func touchesBegan(_ touches: Set<UITouch>) {
        guard isEnabled else { return }
        for touch in touches {
            let p = touch.location(in: hud)
            // Zones flottantes : moitié inférieure, gauche/droite du centre.
            guard p.y < screenSize.height * 0.15 else { continue }
            if p.x < 0, moveTouch == nil {
                moveTouch = touch
                moveStick.activate(at: p)
                Haptics.joystickStarted()
            } else if p.x >= 0, aimTouch == nil {
                aimTouch = touch
                aimStick.activate(at: p)
                Haptics.joystickStarted()
            }
        }
    }

    func touchesMoved(_ touches: Set<UITouch>) {
        for touch in touches {
            let p = touch.location(in: hud)
            if touch === moveTouch {
                moveStick.move(to: p)
            } else if touch === aimTouch {
                aimStick.move(to: p)
            }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch === moveTouch {
                moveTouch = nil
                moveStick.deactivate()
            } else if touch === aimTouch {
                aimTouch = nil
                aimStick.deactivate()
            }
        }
    }

    private func releaseAll() {
        moveTouch = nil
        aimTouch = nil
        moveStick.deactivate()
        aimStick.deactivate()
    }
}
