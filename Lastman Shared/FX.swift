//
//  FX.swift
//  Lastman
//
//  Juice (SPEC §8) : muzzle flash, étincelles d'impact, poof de mort.
//  Particules « maison » (petits SKShapeNode animés) pour rester sans assets.
//  Le screen shake est géré par GameScene (offset caméra).
//

import SpriteKit

enum FX {

    static func muzzleFlash(at point: CGPoint, in scene: SKScene) {
        let flash = SKShapeNode(circleOfRadius: 9)
        flash.position = point
        flash.fillColor = SKColor(white: 1, alpha: 0.9)
        flash.strokeColor = .clear
        flash.zPosition = 9
        flash.setScale(0.4)
        scene.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.08), .fadeOut(withDuration: 0.08)]),
            .removeFromParent(),
        ]))
    }

    static func impactSparks(at point: CGPoint, in scene: SKScene) {
        burst(at: point, count: 6, color: .white, speed: 90, size: 3, life: 0.25, in: scene)
    }

    static func deathPoof(at point: CGPoint, color: SKColor, in scene: SKScene) {
        burst(at: point, count: 16, color: color, speed: 160, size: 5, life: 0.5, in: scene)
        burst(at: point, count: 10, color: .white, speed: 110, size: 4, life: 0.45, in: scene)
    }

    private static func burst(at point: CGPoint, count: Int, color: SKColor,
                              speed: CGFloat, size: CGFloat, life: TimeInterval, in scene: SKScene) {
        for _ in 0..<count {
            let p = SKShapeNode(circleOfRadius: size)
            p.position = point
            p.fillColor = color
            p.strokeColor = .clear
            p.zPosition = 60
            scene.addChild(p)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = speed * CGFloat(life) * CGFloat.random(in: 0.4...1.0)
            let dest = point + CGVector(angle: angle) * dist
            p.run(.sequence([
                .group([
                    .move(to: dest, duration: life),
                    .fadeOut(withDuration: life),
                    .scale(to: 0.2, duration: life),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}
