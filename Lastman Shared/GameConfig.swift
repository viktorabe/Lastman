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
    static let playerSpeed: CGFloat = 175          // rythme plus posé, avec le temps de lire un duel
    static let velocityLerpRate: CGFloat = 10.5    // changements contrôlables sans devenir mous
    static let characterRadius: CGFloat = 15
    static let characterVisualScale: CGFloat = 1.18

    // MARK: Tir et combat (SPEC §6.2)
    static let fireInterval: TimeInterval = 0.60
    static let projectileSpeed: CGFloat = 500
    static let projectileRange: CGFloat = 350
    static let projectileDamage: CGFloat = 20
    static let maxHP: CGFloat = 100
    static let autoShootAcquisitionDelay: TimeInterval = 0.50
    static let botAimWindup: TimeInterval = 0.50

    // MARK: Objets cassables et pickups
    static let maxBreakables = 9
    static let initialBreakableCountRange = 7...9
    static let minimumHealBreakables = 3
    static let breakableRespawnDelayRange: ClosedRange<TimeInterval> = 4.5...9.5
    static let breakableRespawnBatchRange = 1...2
    static let breakableRadius: CGFloat = 18
    static let breakableHP: CGFloat = 40
    static let breakableSpawnInset: CGFloat = 90
    static let breakableMinDistanceFromCharacter: CGFloat = 120
    static let breakableMinDistanceFromObject: CGFloat = 130
    static let pickupRadius: CGFloat = 12
    static let healAmount: CGFloat = 28
    static let speedBoostDuration: TimeInterval = 4
    static let speedBoostMultiplier: CGFloat = 1.35
    static let explosiveRadius: CGFloat = 120
    static let explosiveDamage: CGFloat = 32
    static let shieldDuration: TimeInterval = 7
    static let topThreeZoneShrinkMultiplier: CGFloat = 0.55

    // MARK: Buissons (SPEC §6.3)
    static let bushHiddenAlpha: CGFloat = 0.15
    static let bushRevealAfterShot: TimeInterval = 1.0
    static let bushRevealDistance: CGFloat = 60

    // MARK: Zone (SPEC §6.4)
    static let zoneStages: [CGFloat] = [1.0, 0.70, 0.45, 0.25, 0.10, 0.02]
    static let zoneShrinkInterval: TimeInterval = 15
    static let zoneShrinkDuration: TimeInterval = 2.6
    static let poisonDPS: CGFloat = 7
    static let zoneEdgeMargin: CGFloat = 80        // marge déclenchant avoidZone pendant un palier

    // MARK: Bots (SPEC §7)
    static let visionRadius: CGFloat = 400
    static let targetMemoryDuration: TimeInterval = 2.0
    static let engageDistance: CGFloat = 250       // distance optimale maintenue en attack
    static let fleeSafeDistance: CGFloat = 500     // distance de sécurité pour sortir de flee
    static let botSeekHealThreshold: CGFloat = 0.45
    static let botHealObjectiveRadius: CGFloat = 520

    // MARK: Arène
    static let arenaSize = CGSize(width: 1200, height: 1600)
    static let cameraZoom: CGFloat = 1.42          // personnages et impacts plus présents
    static let landscapeCameraZoom: CGFloat = 1.12

    // MARK: Match
    static let countdownSeconds = 2
    static let quickRestartCountdownSeconds = 1
    static let killStreakWindow: TimeInterval = 7
    static let hitStopDuration: TimeInterval = 0.055
    static let killHitStopDuration: TimeInterval = 0.11
    static let botCountRange = 1...9
    static let defaultBotCount = 5
}

// MARK: - Armes joueur

enum WeaponStyle: Int, CaseIterable {
    case normal = 0
    case heavy = 1
    case sniper = 2

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .heavy: return "Lourd"
        case .sniper: return "Sniper"
        }
    }

    var menuTitle: String {
        switch self {
        case .normal: return "NORMAL"
        case .heavy: return "LOURD"
        case .sniper: return "SNIPER"
        }
    }

    var menuSubtitle: String {
        switch self {
        case .normal: return "tir équilibré · portée moyenne"
        case .heavy: return "grosses balles · courte portée"
        case .sniper: return "petites balles · longue portée"
        }
    }

    var projectileRadius: CGFloat {
        switch self {
        case .normal: return 3
        case .heavy: return 7
        case .sniper: return 2.6
        }
    }

    var projectileDamage: CGFloat {
        switch self {
        case .normal: return GameConfig.projectileDamage
        case .heavy: return 34
        case .sniper: return 24
        }
    }

    var projectileSpeed: CGFloat {
        switch self {
        case .normal: return GameConfig.projectileSpeed
        case .heavy: return 430
        case .sniper: return 760
        }
    }

    var projectileRange: CGFloat {
        switch self {
        case .normal: return GameConfig.projectileRange
        case .heavy: return 220
        case .sniper: return 640
        }
    }

    var fireInterval: TimeInterval {
        switch self {
        case .normal: return GameConfig.fireInterval
        case .heavy: return 0.88
        case .sniper: return 1.05
        }
    }

    var muzzleScale: CGFloat {
        switch self {
        case .normal: return 1
        case .heavy: return 1.65
        case .sniper: return 0.75
        }
    }

    var shotShake: CGFloat {
        switch self {
        case .normal: return 0.4
        case .heavy: return 2.2
        case .sniper: return 1.0
        }
    }

    var recoilImpulse: CGFloat {
        switch self {
        case .normal: return 0
        case .heavy: return 92
        case .sniper: return 0
        }
    }

    var hasAimTrace: Bool {
        self == .sniper
    }
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
    static let breakable: UInt32        = 1 << 7
    static let healPickup: UInt32       = 1 << 8

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
        case .easy: return 10
        case .medium: return 4
        case .hard: return 1.5
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
