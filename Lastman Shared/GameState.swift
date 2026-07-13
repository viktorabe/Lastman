//
//  GameState.swift
//  Lastman
//
//  Source de vérité logique du match (SPEC §3/§9) : les SKNode ne font que
//  refléter cet état, ils ne le portent pas seuls.
//

import Foundation
import CoreGraphics

struct MatchSummary {
    let victory: Bool
    let rank: Int
    let total: Int
    let survivalTime: TimeInterval
    let bestSurvivalTime: TimeInterval
    let isNewBestSurvival: Bool
    let playerKills: Int
    let playerDamageDealt: Int
    let playerDamageTaken: Int
    let playerPickupsCollected: Int
    let playerBreakablesDestroyed: Int
    let bestKillStreak: Int
    let deathCause: String
}

/// États de match internes (SPEC §5).
enum MatchPhase {
    case preparing
    case countdown
    case active
    case ended
}

final class GameState {

    private(set) var characters: [Character] = []
    private(set) var player: Character!
    var phase: MatchPhase = .preparing
    private var matchStartTime: TimeInterval = 0
    private var matchEndTime: TimeInterval?

    private(set) var playerKills = 0
    private(set) var playerDamageDealt: CGFloat = 0
    private(set) var playerDamageTaken: CGFloat = 0
    private(set) var playerPickupsCollected = 0
    private(set) var playerBreakablesDestroyed = 0
    private(set) var currentKillStreak = 0
    private(set) var bestKillStreak = 0
    private var lastPlayerKillTime: TimeInterval = -.infinity
    private(set) var deathCause = "Dernier debout."

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

    func startMatch(at time: TimeInterval) {
        matchStartTime = time
        matchEndTime = nil
    }

    @discardableResult
    func recordPlayerKill(at time: TimeInterval) -> Int {
        playerKills += 1
        currentKillStreak = time - lastPlayerKillTime <= GameConfig.killStreakWindow
            ? currentKillStreak + 1
            : 1
        lastPlayerKillTime = time
        bestKillStreak = max(bestKillStreak, currentKillStreak)
        return currentKillStreak
    }

    func breakPlayerKillStreak() {
        currentKillStreak = 0
        lastPlayerKillTime = -.infinity
    }

    func recordPlayerDamageDealt(_ amount: CGFloat) {
        playerDamageDealt += max(0, amount)
    }

    func recordPlayerDamageTaken(_ amount: CGFloat) {
        playerDamageTaken += max(0, amount)
    }

    func recordPlayerPickup() {
        playerPickupsCollected += 1
    }

    func recordPlayerBreakableDestroyed() {
        playerBreakablesDestroyed += 1
    }

    func recordPlayerDeath(cause: String) {
        deathCause = cause
    }

    func finishMatch(victory: Bool, at time: TimeInterval) -> MatchSummary {
        matchEndTime = time
        if victory {
            deathCause = "Dernier debout."
        }

        let survived = max(0, time - matchStartTime)
        let previousBest = GameSettings.bestSurvivalTime
        let newBest = survived > previousBest
        if newBest {
            GameSettings.bestSurvivalTime = survived
        }

        return MatchSummary(
            victory: victory,
            rank: playerRank,
            total: totalCount,
            survivalTime: survived,
            bestSurvivalTime: max(previousBest, survived),
            isNewBestSurvival: newBest,
            playerKills: playerKills,
            playerDamageDealt: Int(playerDamageDealt.rounded()),
            playerDamageTaken: Int(playerDamageTaken.rounded()),
            playerPickupsCollected: playerPickupsCollected,
            playerBreakablesDestroyed: playerBreakablesDestroyed,
            bestKillStreak: bestKillStreak,
            deathCause: deathCause
        )
    }
}
