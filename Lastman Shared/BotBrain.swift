//
//  BotBrain.swift
//  Lastman
//
//  FSM des bots (SPEC §7) : GKStateMachine + perception + difficulté.
//  Le cerveau lit le monde, écrit uniquement moveIntent / aimIntent du bot ;
//  le tir effectif et la cadence restent gérés par CombatSystem.
//

import SpriteKit
import GameplayKit

/// Ce que le cerveau peut interroger dans le monde. GameScene l'implémente.
protocol BotWorld: AnyObject {
    var allCharacters: [Character] { get }
    var zone: ZoneSystem { get }
    var bushSystem: BushSystem { get }
    func healingObjective(for character: Character) -> HealingObjective?
    func lineOfSightClear(from: CGPoint, to: CGPoint) -> Bool
}

enum BotPersonality: CaseIterable {
    case aggressive
    case cautious
    case opportunist

    var label: String {
        switch self {
        case .aggressive: return "Aggro"
        case .cautious: return "Prudent"
        case .opportunist: return "Opportuniste"
        }
    }

    var aggressionMultiplier: CGFloat {
        switch self {
        case .aggressive: return 1.22
        case .cautious: return 0.88
        case .opportunist: return 1.0
        }
    }

    var healThresholdOffset: CGFloat {
        switch self {
        case .aggressive: return -0.08
        case .cautious: return 0.16
        case .opportunist: return 0.04
        }
    }

    var strafeMultiplier: CGFloat {
        switch self {
        case .aggressive: return 1.0
        case .cautious: return 0.72
        case .opportunist: return 0.9
        }
    }
}

// MARK: - Cerveau

final class BotBrain {

    unowned let bot: Character
    unowned let world: BotWorld
    let difficulty: Difficulty
    let personality: BotPersonality

    private var machine: GKStateMachine!

    // MARK: Perception (SPEC §7.1)

    /// Cible actuellement perçue (après reactionDelay).
    private(set) var visibleTarget: Character?
    /// Dernière position connue, gardée ~2 s après perte de vue.
    private(set) var lastKnownPosition: CGPoint?
    private var memoryRemaining: TimeInterval = 0
    private var reactionRemaining: TimeInterval
    private var isAlerted = false

    var hasThreat: Bool { visibleTarget != nil || lastKnownPosition != nil }
    var aimErrorRadians: CGFloat { difficulty.aimErrorDegrees.degreesToRadians }
    var aggressionDistance: CGFloat { difficulty.aggression * personality.aggressionMultiplier }
    var seekHealThreshold: CGFloat {
        min(0.82, max(0.18, GameConfig.botSeekHealThreshold + personality.healThresholdOffset))
    }

    init(bot: Character, world: BotWorld, difficulty: Difficulty, personality: BotPersonality) {
        self.bot = bot
        self.world = world
        self.difficulty = difficulty
        self.personality = personality
        self.reactionRemaining = difficulty.reactionDelay

        machine = GKStateMachine(states: [
            BotIdleState(brain: self),
            BotWanderState(brain: self),
            BotChaseState(brain: self),
            BotAttackState(brain: self),
            BotSeekHealState(brain: self),
            BotFleeState(brain: self),
            BotAvoidZoneState(brain: self),
            BotDeadState(brain: self),
        ])
        enter(BotIdleState.self)
    }

    /// Transition + hook d'entrée (begin), sans dépendre des overrides GKState.
    func enter(_ stateClass: AnyClass) {
        guard !(machine.currentState?.isMember(of: stateClass) ?? false) else { return }
        if machine.enter(stateClass) {
            (machine.currentState as? BotState)?.begin()
        }
    }

    // MARK: Boucle

    func update(dt: TimeInterval) {
        guard bot.isAlive else {
            enter(BotDeadState.self)
            return
        }

        updatePerception(dt: dt)

        // Overrides de priorité (SPEC §7.3) :
        // avoidZone est prioritaire absolu, puis un bot blessé cherche à se soigner.
        if world.zone.isInDanger(bot.position) {
            enter(BotAvoidZoneState.self)
        } else if bot.hpFraction < seekHealThreshold,
                  world.healingObjective(for: bot) != nil,
                  !(machine.currentState is BotAvoidZoneState) {
            enter(BotSeekHealState.self)
        } else if bot.hpFraction < difficulty.fleeThreshold, hasThreat,
                  !(machine.currentState is BotAvoidZoneState) {
            enter(BotFleeState.self)
        }

        (machine.currentState as? BotState)?.tick(dt: dt)
    }

    private func updatePerception(dt: TimeInterval) {
        // Cible candidate : le vivant le plus proche, dans le rayon de vision,
        // et pas caché dans un buisson (SPEC §7.1).
        let candidates = world.allCharacters.filter { other in
            other !== bot
                && other.isAlive
                && other.position.distance(to: bot.position) < GameConfig.visionRadius
                && world.bushSystem.canPerceive(other)
        }
        let nearest = candidates.min {
            $0.position.distance(to: bot.position) < $1.position.distance(to: bot.position)
        }

        if let nearest {
            if !isAlerted {
                // Délai entre perception et première action (SPEC §7.4).
                reactionRemaining -= dt
                if reactionRemaining <= 0 {
                    isAlerted = true
                }
            }
            if isAlerted {
                visibleTarget = nearest
                lastKnownPosition = nearest.position
                memoryRemaining = GameConfig.targetMemoryDuration
            }
        } else {
            visibleTarget = nil
            if lastKnownPosition != nil {
                memoryRemaining -= dt
                if memoryRemaining <= 0 {
                    lastKnownPosition = nil
                    isAlerted = false
                    reactionRemaining = difficulty.reactionDelay
                }
            } else {
                isAlerted = false
                reactionRemaining = difficulty.reactionDelay
            }
        }
    }
}

// MARK: - États

/// Base commune : begin() à l'entrée, tick() chaque frame.
class BotState: GKState {
    unowned let brain: BotBrain
    var bot: Character { brain.bot }

    init(brain: BotBrain) {
        self.brain = brain
        super.init()
    }

    func begin() {}
    func tick(dt: TimeInterval) {}

    /// Steering simple : vecteur normalisé vers un point (SPEC §3, pas de pathfinding).
    func direction(to point: CGPoint) -> CGVector {
        CGVector(from: bot.position, to: point).normalized
    }
}

/// Immobile, scanne. Très court, transitoire au spawn.
final class BotIdleState: BotState {
    private var remaining: TimeInterval = 0

    override func begin() {
        remaining = .random(in: 0.2...0.6)
        bot.moveIntent = .zero
        bot.aimIntent = nil
    }

    override func tick(dt: TimeInterval) {
        remaining -= dt
        if brain.visibleTarget != nil {
            brain.enter(BotChaseState.self)
        } else if remaining <= 0 {
            brain.enter(BotWanderState.self)
        }
    }
}

/// Se déplace vers un point aléatoire dans la zone safe, cherche une cible en route.
final class BotWanderState: BotState {
    private var destination: CGPoint = .zero
    private var repickTimer: TimeInterval = 0

    override func begin() {
        pickDestination()
        bot.aimIntent = nil
    }

    private func pickDestination() {
        destination = brain.world.zone.randomSafePoint()
        repickTimer = .random(in: 3.5...6)
    }

    override func tick(dt: TimeInterval) {
        if brain.visibleTarget != nil {
            brain.enter(BotChaseState.self)
            return
        }
        repickTimer -= dt
        if bot.position.distance(to: destination) < 25 || repickTimer <= 0 {
            pickDestination()
        }
        bot.moveIntent = direction(to: destination) * 0.85
    }
}

/// Cible connue mais hors de portée de tir : avance pour entrer à portée.
final class BotChaseState: BotState {
    override func begin() {
        bot.aimIntent = nil
    }

    override func tick(dt: TimeInterval) {
        if let target = brain.visibleTarget {
            let dist = bot.position.distance(to: target.position)
            if dist <= brain.aggressionDistance,
               brain.world.lineOfSightClear(from: bot.position, to: target.position) {
                brain.enter(BotAttackState.self)
                return
            }
            bot.moveIntent = direction(to: target.position)
        } else if let memory = brain.lastKnownPosition {
            // Mémoire : file vers la dernière position connue (SPEC §7.1).
            if bot.position.distance(to: memory) < 20 {
                bot.moveIntent = .zero
            } else {
                bot.moveIntent = direction(to: memory)
            }
        } else {
            brain.enter(BotWanderState.self)
        }
    }
}

/// À portée + ligne de vue : strafe en tirant avec aimError, maintient ~250 pt.
final class BotAttackState: BotState {
    private var strafeSign: CGFloat = 1
    private var strafeFlipTimer: TimeInterval = 0

    override func begin() {
        strafeSign = Bool.random() ? 1 : -1
        strafeFlipTimer = .random(in: 0.8...1.6)
    }

    override func tick(dt: TimeInterval) {
        guard let target = brain.visibleTarget else {
            brain.enter(BotChaseState.self)
            return
        }
        let dist = bot.position.distance(to: target.position)
        if dist > brain.aggressionDistance
            || !brain.world.lineOfSightClear(from: bot.position, to: target.position) {
            bot.aimIntent = nil
            brain.enter(BotChaseState.self)
            return
        }

        // Strafe latéral + correction radiale vers la distance d'engagement optimale.
        strafeFlipTimer -= dt
        if strafeFlipTimer <= 0 {
            strafeSign *= -1
            strafeFlipTimer = .random(in: 0.8...1.6)
        }
        let toTarget = direction(to: target.position)
        let radialAmount = min(max((dist - GameConfig.engageDistance) / 120, -1), 1)
        let movement = toTarget * radialAmount + toTarget.perpendicular * (strafeSign * 0.8)
        bot.moveIntent = movement.normalized * (0.9 * brain.personality.strafeMultiplier)

        // Tir avec bruit gaussien sur l'angle (SPEC §7.4).
        let aimAngle = toTarget.angle + gaussianRandom(stdDev: brain.aimErrorRadians)
        bot.aimIntent = CGVector(angle: aimAngle)
    }
}

/// PV bas : s'éloigne de la menace, vise un buisson pour se cacher.
final class BotFleeState: BotState {
    override func begin() {
        bot.aimIntent = nil
    }

    override func tick(dt: TimeInterval) {
        guard let threatPoint = brain.visibleTarget?.position ?? brain.lastKnownPosition else {
            brain.enter(BotWanderState.self)
            return
        }
        let distToThreat = bot.position.distance(to: threatPoint)
        if distToThreat > GameConfig.fleeSafeDistance {
            brain.enter(BotWanderState.self)
            return
        }

        // Déjà caché et pas révélé : rester immobile, la menace ne nous voit plus.
        if bot.isConcealed {
            bot.moveIntent = .zero
            return
        }

        let away = CGVector(from: threatPoint, to: bot.position).normalized
        // Si un buisson est accessible dans la zone safe, s'y réfugier.
        if let bush = brain.world.bushSystem.nearestBush(to: bot.position),
           bush.center.distance(to: bot.position) < 350,
           !brain.world.zone.isOutside(bush.center),
           CGVector(from: bot.position, to: bush.center).normalized.dx * away.dx
             + CGVector(from: bot.position, to: bush.center).normalized.dy * away.dy > -0.3 {
            bot.moveIntent = direction(to: bush.center)
        } else {
            bot.moveIntent = away
        }
    }
}

/// PV bas : conteste un soin déjà au sol, ou casse une caisse de soin proche.
final class BotSeekHealState: BotState {
    override func begin() {
        bot.aimIntent = nil
    }

    override func tick(dt: TimeInterval) {
        if bot.hpFraction > brain.seekHealThreshold + 0.18 {
            brain.enter(BotWanderState.self)
            return
        }

        guard let objective = brain.world.healingObjective(for: bot) else {
            brain.enter(brain.hasThreat ? BotFleeState.self : BotWanderState.self)
            return
        }

        let dist = bot.position.distance(to: objective.position)
        switch objective.source {
        case .pickup:
            bot.aimIntent = nil
            bot.moveIntent = dist < 16 ? .zero : direction(to: objective.position)

        case .breakable:
            let toCrate = direction(to: objective.position)
            bot.aimIntent = toCrate
            if dist > min(GameConfig.projectileRange * 0.8, 280) {
                bot.moveIntent = toCrate * 0.8
            } else {
                bot.moveIntent = .zero
            }
        }
    }
}

/// Priorité absolue : hors zone ou zone en fermeture proche → rejoindre le centre.
final class BotAvoidZoneState: BotState {
    override func begin() {
        // Interrompt tout combat (SPEC §7.2).
        bot.aimIntent = nil
    }

    override func tick(dt: TimeInterval) {
        let zone = brain.world.zone
        let safeEnough = !zone.isInDanger(bot.position)
            && zone.distanceToEdge(from: bot.position) > GameConfig.zoneEdgeMargin * 1.5
        if safeEnough {
            brain.enter(BotWanderState.self)
            return
        }
        bot.moveIntent = direction(to: zone.center)
    }
}

/// Désactivé, retiré de la logique.
final class BotDeadState: BotState {
    override func begin() {
        bot.moveIntent = .zero
        bot.aimIntent = nil
    }
}
