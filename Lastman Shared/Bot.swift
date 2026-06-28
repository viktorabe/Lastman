//
//  Bot.swift
//  Lastman
//
//  Adversaire piloté par une FSM (cf. BotBrain). Le bot ne « voit » que le
//  joueur en v1 (solo contre des bots, SPEC §1) ; la zone fait le reste.
//

import SpriteKit

/// Interface minimale que la GameScene expose au cerveau des bots.
protocol BotWorld: AnyObject {
    var player: Player { get }
    var zoneCenter: CGPoint { get }
    var zoneRadius: CGFloat { get }
    var zoneIsShrinking: Bool { get }
    func isInsideZone(_ p: CGPoint) -> Bool
    func hasLineOfSight(from a: CGPoint, to b: CGPoint) -> Bool
    func fire(from c: Character, direction: CGVector, now: TimeInterval)
    func randomPointInZone() -> CGPoint
}

final class Bot: Character {
    var brain: BotBrain!

    init(color: SKColor, position: CGPoint, difficulty: Difficulty, world: BotWorld) {
        super.init(isPlayer: false, color: color, position: position)
        brain = BotBrain(bot: self, world: world, difficulty: difficulty)
    }
}
