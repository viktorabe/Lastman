//
//  BotBrain.swift
//  Lastman
//
//  FSM des bots (SPEC §7). Implémentée comme un enum + switch piloté chaque
//  frame (steering simple à la main, pas de pathfinding — SPEC §3). La
//  perception (vision, occlusion buisson, mémoire, reactionDelay) et les
//  paramètres de difficulté rendent les bots crédibles sans tricher.
//

import SpriteKit

final class BotBrain {

    enum State: String { case idle, wander, chase, attack, flee, avoidZone, dead }

    private(set) var state: State = .idle

    private unowned let bot: Bot
    private unowned let world: BotWorld
    private let difficulty: Difficulty

    // Perception / mémoire
    private var lastKnownPos: CGPoint?
    private var lastSeenTime: TimeInterval = 0
    private var perceivedSince: TimeInterval?

    // Wander / strafe
    private var wanderTarget: CGPoint?
    private var wanderRetime: TimeInterval = 0
    private var strafeDir: CGFloat = 1
    private var strafeFlip: TimeInterval = 0

    init(bot: Bot, world: BotWorld, difficulty: Difficulty) {
        self.bot = bot
        self.world = world
        self.difficulty = difficulty
    }

    func update(now: TimeInterval, dt: TimeInterval) {
        guard bot.isAlive else { state = .dead; return }
        let pos = bot.position
        let player = world.player

        // 1) avoidZone — priorité absolue (SPEC §7.3).
        let outside = !world.isInsideZone(pos)
        let nearShrinkingEdge = world.zoneIsShrinking
            && (world.zoneRadius - pos.distance(to: world.zoneCenter)) < GameConfig.zoneAvoidMargin
        if outside || nearShrinkingEdge {
            state = .avoidZone
            steer(toward: world.zoneCenter)
            return
        }

        // 2) Perception du joueur (la seule cible en v1).
        var canSee = false
        if player.isAlive {
            let d = pos.distance(to: player.position)
            if d <= GameConfig.visionRadius
                && !player.isHiddenInBush
                && world.hasLineOfSight(from: pos, to: player.position) {
                canSee = true
                lastKnownPos = player.position
                lastSeenTime = now
                if perceivedSince == nil { perceivedSince = now }
            }
        }
        if !canSee { perceivedSince = nil }

        let reacted = perceivedSince.map { now - $0 >= difficulty.reactionDelay } ?? false
        let remembers = lastKnownPos != nil && now - lastSeenTime < GameConfig.targetMemory

        // 3) flee — PV bas tant qu'une menace est connue.
        if bot.hpFraction < difficulty.fleeThresholdPct && (canSee || remembers) {
            state = .flee
            steer(away: lastKnownPos ?? player.position)
            return
        }

        // 4) chase / attack / wander.
        if canSee && reacted {
            let d = pos.distance(to: player.position)
            if d <= difficulty.engageDistance {
                state = .attack
                attack(target: player, now: now)
            } else {
                state = .chase
                steer(toward: player.position)
            }
        } else if let lk = lastKnownPos, remembers {
            state = .chase
            steer(toward: lk)
        } else {
            state = .wander
            wander(now: now)
        }
    }

    // MARK: Comportements

    private func steer(toward point: CGPoint) {
        bot.applyMovement((point - bot.position).normalized())
    }

    private func steer(away from: CGPoint) {
        bot.applyMovement((bot.position - from).normalized())
    }

    private func wander(now: TimeInterval) {
        let reached = wanderTarget.map { bot.position.distance(to: $0) < 40 } ?? true
        if wanderTarget == nil || reached || now > wanderRetime {
            wanderTarget = world.randomPointInZone()
            wanderRetime = now + Double.random(in: 2...4)
        }
        if let t = wanderTarget { steer(toward: t) }
    }

    private func attack(target: Character, now: TimeInterval) {
        let to = target.position - bot.position
        let dir = to.normalized()
        let d = to.length
        let engage = difficulty.engageDistance

        // Maintien d'une distance d'engagement + strafe latéral (SPEC §7.2).
        var radial: CGFloat = 0
        if d > engage * 1.05 { radial = 0.6 } else if d < engage * 0.8 { radial = -0.7 }
        if now > strafeFlip { strafeDir *= -1; strafeFlip = now + Double.random(in: 1...2) }
        let perp = CGVector(dx: -dir.dy, dy: dir.dx) * (strafeDir * 0.7)
        bot.applyMovement((dir * radial) + perp)

        bot.face(direction: dir)

        // Tir avec aimError gaussien (le levier de crédibilité, SPEC §7.4).
        let err = RandomMath.gaussian(mean: 0, sd: difficulty.aimErrorDegrees * .pi / 180)
        world.fire(from: bot, direction: CGVector(angle: dir.angle + err), now: now)
    }
}
