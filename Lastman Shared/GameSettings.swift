//
//  GameSettings.swift
//  Lastman
//
//  Réglages persistés (UserDefaults) : difficulté + nombre de bots (SPEC §5).
//

import Foundation

enum GameSettings {

    private static let kDifficulty = "settings.difficulty"
    private static let kBotCount = "settings.botCount"
    private static let kBotCountSet = "settings.botCountSet"

    static var difficulty: Difficulty {
        // `integer(forKey:)` renvoie 0 (= .easy) si la clé est absente : on teste
        // donc l'existence pour conserver Moyen comme défaut.
        get {
            guard UserDefaults.standard.object(forKey: kDifficulty) != nil else { return .medium }
            return Difficulty(rawValue: UserDefaults.standard.integer(forKey: kDifficulty)) ?? .medium
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: kDifficulty) }
    }

    /// Nombre de bots. Si jamais réglé par le joueur, suit le défaut de la difficulté.
    static var botCount: Int {
        get {
            let d = UserDefaults.standard
            return d.bool(forKey: kBotCountSet) ? d.integer(forKey: kBotCount) : difficulty.defaultBotCount
        }
        set {
            let d = UserDefaults.standard
            d.set(min(max(newValue, 1), 10), forKey: kBotCount)
            d.set(true, forKey: kBotCountSet)
        }
    }
}
