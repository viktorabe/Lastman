//
//  Player.swift
//  Lastman
//
//  Stickman du joueur. Mappe les intents des deux joysticks (SPEC §9).
//

import SpriteKit

final class Player: Character {

    /// Couleur signature du joueur.
    static let signature = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)

    init(position: CGPoint) {
        super.init(isPlayer: true, color: Player.signature, position: position)
    }

    /// Applique les entrées de la frame.
    /// - move : joystick gauche (déplacement).
    /// - aim : joystick droit (visée) ; oriente le stickman si poussé.
    func apply(move: CGVector, aim: CGVector) {
        applyMovement(move)
        if aim.length > 0.001 {
            face(direction: aim)
        }
    }
}
