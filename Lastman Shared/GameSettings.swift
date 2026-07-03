//
//  GameSettings.swift
//  Lastman
//
//  Réglages persistés localement (SPEC §5 : UserDefaults).
//

import Foundation

enum GameSettings {
    private static let difficultyKey = "lastman.difficulty"
    private static let botCountKey = "lastman.botCount"

    static var difficulty: Difficulty {
        get {
            guard UserDefaults.standard.object(forKey: difficultyKey) != nil else { return .medium }
            return Difficulty(rawValue: UserDefaults.standard.integer(forKey: difficultyKey)) ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: difficultyKey)
        }
    }

    static var botCount: Int {
        get {
            guard UserDefaults.standard.object(forKey: botCountKey) != nil else {
                return GameConfig.defaultBotCount
            }
            let stored = UserDefaults.standard.integer(forKey: botCountKey)
            return min(max(stored, GameConfig.botCountRange.lowerBound), GameConfig.botCountRange.upperBound)
        }
        set {
            let clamped = min(max(newValue, GameConfig.botCountRange.lowerBound), GameConfig.botCountRange.upperBound)
            UserDefaults.standard.set(clamped, forKey: botCountKey)
        }
    }
}
