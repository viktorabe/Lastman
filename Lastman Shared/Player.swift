//
//  Player.swift
//  Lastman
//
//  PlayerController : mappe les intents des joysticks vers le personnage joueur.
//

import Foundation

final class PlayerController {

    let character: Character
    private let input: InputController

    init(character: Character, input: InputController) {
        self.character = character
        self.input = input
    }

    func update() {
        guard character.isAlive else { return }
        character.moveIntent = input.moveVector
        character.aimIntent = input.isAiming ? input.aimVector : nil
    }
}
