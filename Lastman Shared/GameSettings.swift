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
    private static let hapticsEnabledKey = "lastman.hapticsEnabled"
    private static let soundEnabledKey = "lastman.soundEnabled"
    private static let landscapeModeEnabledKey = "lastman.landscapeModeEnabled"
    private static let weaponStyleKey = "lastman.weaponStyle"
    private static let bestSurvivalTimeKey = "lastman.bestSurvivalTime"
    static let orientationPreferenceDidChange = Notification.Name("lastman.orientationPreferenceDidChange")

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

    static var hapticsEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: hapticsEnabledKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: hapticsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hapticsEnabledKey)
        }
    }

    static var soundEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: soundEnabledKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: soundEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: soundEnabledKey)
        }
    }

    static var landscapeModeEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: landscapeModeEnabledKey) != nil else { return false }
            return UserDefaults.standard.bool(forKey: landscapeModeEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: landscapeModeEnabledKey)
            NotificationCenter.default.post(name: orientationPreferenceDidChange, object: nil)
        }
    }

    static var weaponStyle: WeaponStyle {
        get {
            guard UserDefaults.standard.object(forKey: weaponStyleKey) != nil else { return .normal }
            return WeaponStyle(rawValue: UserDefaults.standard.integer(forKey: weaponStyleKey)) ?? .normal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: weaponStyleKey)
        }
    }

    static var bestSurvivalTime: TimeInterval {
        get {
            UserDefaults.standard.double(forKey: bestSurvivalTimeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bestSurvivalTimeKey)
        }
    }
}
