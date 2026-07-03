//
//  GameState.swift
//  Lastman
//
//  Source de vérité logique du match (SPEC §3/§9) : les SKNode ne font que
//  refléter cet état, ils ne le portent pas seuls.
//

import Foundation

/// États de match internes (SPEC §5).
enum MatchPhase {
    case countdown
    case active
    case ended
}

final class GameState {

    private(set) var characters: [Character] = []
    private(set) var player: Character!
    var phase: MatchPhase = .countdown

    var totalCount: Int { characters.count }
    var aliveCharacters: [Character] { characters.filter { $0.isAlive } }
    var aliveCount: Int { aliveCharacters.count }

    func addPlayer(_ character: Character) {
        player = character
        characters.append(character)
    }

    func addBot(_ character: Character) {
        characters.append(character)
    }

    /// Rang du joueur : #1 s'il gagne, sinon (survivants + 1) au moment de sa mort.
    var playerRank: Int {
        player.isAlive ? 1 : aliveCount + 1
    }
}
