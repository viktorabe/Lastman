//
//  GameConfig.swift
//  Lastman
//
//  Toutes les constantes de gameplay au même endroit (SPEC §11).
//  Tuner ici, pas dans le code des systèmes.
//

import Foundation
import CoreGraphics

enum GameConfig {

    // MARK: Déplacement (SPEC §6.1)
    static let playerSpeed: CGFloat = 180          // pt/s, identique joueur et bots
    static let velocityLerpRate: CGFloat = 12      // réactivité (léger easing, pas d'inertie)
    static let characterRadius: CGFloat = 13

    // MARK: Tir et combat (SPEC §6.2)
    static let fireInterval: TimeInterval = 0.35
    static let projectileSpeed: CGFloat = 500
    static let projectileRange: CGFloat = 350
    static let projectileDamage: CGFloat = 20
    static let maxHP: CGFloat = 100

    // MARK: Buissons (SPEC §6.3)
    static let bushHiddenAlpha: CGFloat = 0.15
    static let bushRevealAfterShot: TimeInterval = 1.0
    static let bushRevealDistance: CGFloat = 60

    // MARK: Zone (SPEC §6.4)
    static let zoneStages: [CGFloat] = [1.0, 0.70, 0.45, 0.25, 0.10, 0.02]
    static let zoneShrinkInterval: TimeInterval = 20
    static let zoneShrinkDuration: TimeInterval = 3
    static let poisonDPS: CGFloat = 5
    static let zoneEdgeMargin: CGFloat = 80        // marge déclenchant avoidZone pendant un palier

    // MARK: Bots (SPEC §7)
    static let visionRadius: CGFloat = 400
    static let targetMemoryDuration: TimeInterval = 2.0
    static let engageDistance: CGFloat = 250       // distance optimale maintenue en attack
    static let fleeSafeDistance: CGFloat = 500     // distance de sécurité pour sortir de flee

    // MARK: Arène
    static let arenaSize = CGSize(width: 1200, height: 1600)
    static let cameraZoom: CGFloat = 1.7           // >1 = dézoomé (on voit plus large que l'écran)

    // MARK: Match
    static let countdownSeconds = 3
    static let botCountRange = 1...9
    static let defaultBotCount = 5
}

// MARK: - Catégories de physique (SPEC §3)

enum PhysicsCategory {
    static let none: UInt32             = 0
    static let player: UInt32           = 1 << 0
    static let bot: UInt32              = 1 << 1
    static let projectilePlayer: UInt32 = 1 << 2
    static let projectileBot: UInt32    = 1 << 3
    static let wall: UInt32             = 1 << 4
    static let bushSensor: UInt32       = 1 << 5
    static let zoneSensor: UInt32       = 1 << 6

    static let anyCharacter: UInt32  = player | bot
    static let anyProjectile: UInt32 = projectilePlayer | projectileBot
}

// MARK: - Difficulté (SPEC §7.4)

enum Difficulty: Int, CaseIterable {
    case easy = 0
    case medium = 1
    case hard = 2

    var label: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        }
    }

    /// Délai entre la perception d'une cible et la première action (s).
    var reactionDelay: TimeInterval {
        switch self {
        case .easy: return 0.6
        case .medium: return 0.35
        case .hard: return 0.15
        }
    }

    /// Écart-type du bruit gaussien ajouté à l'angle de tir (degrés).
    var aimErrorDegrees: CGFloat {
        switch self {
        case .easy: return 18
        case .medium: return 9
        case .hard: return 3
        }
    }

    /// Portée d'engagement (pt) : distance à laquelle le bot passe de chase à attack.
    var aggression: CGFloat {
        switch self {
        case .easy: return 250
        case .medium: return 350
        case .hard: return 450
        }
    }

    /// Fraction de PV sous laquelle le bot fuit.
    var fleeThreshold: CGFloat {
        switch self {
        case .easy: return 0.50
        case .medium: return 0.30
        case .hard: return 0.15
        }
    }

    var defaultBotCount: Int {
        switch self {
        case .easy: return 3
        case .medium: return 5
        case .hard: return 7
        }
    }
}
