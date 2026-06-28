//
//  GameConfig.swift
//  Lastman
//
//  Constantes centralisées pour tuner vite (cf. SPEC §11) + difficulté (§7.4).
//

import CoreGraphics
import Foundation

enum GameConfig {
    // MARK: Arène
    static let arenaSize = CGSize(width: 1400, height: 2200)
    static let wallThickness: CGFloat = 24

    // MARK: Déplacement (SPEC §6.1)
    static let playerSpeed: CGFloat = 180
    static let characterRadius: CGFloat = 18
    static let moveSmoothing: CGFloat = 0.25

    // MARK: Joysticks (SPEC §4)
    static let joystickRadius: CGFloat = 60
    static let joystickDeadZone: CGFloat = 0.12

    // MARK: Combat (SPEC §6.2)
    static let maxHP: CGFloat = 100
    static let fireInterval: TimeInterval = 0.35
    static let projectileSpeed: CGFloat = 500
    static let projectileRange: CGFloat = 350
    static let projectileDamage: CGFloat = 20
    static let projectileRadius: CGFloat = 5

    // MARK: Buissons (SPEC §6.3)
    static let bushHiddenAlpha: CGFloat = 0.15
    static let bushRevealDuration: TimeInterval = 1.0   // révélé après avoir tiré
    static let bushRevealDistance: CGFloat = 60         // un ennemi plus proche révèle

    // MARK: Zone (SPEC §6.4)
    static let poisonDPS: CGFloat = 5
    /// Paliers de rayon (fraction du rayon initial qui couvre l'arène).
    static let zoneStages: [CGFloat] = [1.0, 0.7, 0.45, 0.25, 0.10, 0.0]
    static let zoneShrinkInterval: TimeInterval = 20    // entre deux paliers
    static let zoneShrinkRate: CGFloat = 90             // pt/s d'animation du rayon
    static let zoneAvoidMargin: CGFloat = 90            // marge avant que les bots fuient le bord

    // MARK: Perception bots (SPEC §7.1)
    static let visionRadius: CGFloat = 400
    static let targetMemory: TimeInterval = 2.0         // dernière position connue

    // MARK: Match
    static let countdownSeconds = 3
}

/// Catégories de collision (bitmask), cf. SPEC §3.
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let bot: UInt32 = 1 << 1
    static let projectilePlayer: UInt32 = 1 << 2
    static let projectileBot: UInt32 = 1 << 3
    static let wall: UInt32 = 1 << 4
}

/// Difficulté : un seul curseur pilote les paramètres des bots (SPEC §7.4).
enum Difficulty: Int, CaseIterable {
    case easy = 0, medium, hard

    var title: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        }
    }

    var reactionDelay: TimeInterval {
        switch self { case .easy: return 0.6; case .medium: return 0.35; case .hard: return 0.15 }
    }
    /// Écart-type du bruit de visée, en degrés.
    var aimErrorDegrees: CGFloat {
        switch self { case .easy: return 18; case .medium: return 9; case .hard: return 3 }
    }
    /// Distance d'engagement (aggression), en points.
    var engageDistance: CGFloat {
        switch self { case .easy: return 250; case .medium: return 350; case .hard: return 450 }
    }
    /// Seuil de fuite, en fraction des PV.
    var fleeThresholdPct: CGFloat {
        switch self { case .easy: return 0.50; case .medium: return 0.30; case .hard: return 0.15 }
    }
    var defaultBotCount: Int {
        switch self { case .easy: return 3; case .medium: return 5; case .hard: return 7 }
    }
}
