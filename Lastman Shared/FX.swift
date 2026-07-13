//
//  FX.swift
//  Lastman
//
//  Le juice (SPEC §8) : muzzle flash, étincelles d'impact, poof de mort.
//  Emitters construits en code (pas de .sks), texture particule générée.
//

import SpriteKit

enum FX {

    /// Petite texture ronde blanche partagée par tous les emitters.
    static let particleTexture: SKTexture = {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }()

    // MARK: - Muzzle flash

    static func muzzleFlash(at point: CGPoint, angle: CGFloat, in parent: SKNode, scale: CGFloat = 1) {
        let flash = SKShapeNode(circleOfRadius: 5)
        flash.position = point
        flash.zRotation = angle
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.zPosition = 16
        flash.xScale = 1.6 * scale
        flash.yScale = scale
        parent.addChild(flash)
        flash.run(.sequence([
            .group([
                .scale(to: 0.2, duration: 0.09),
                .fadeOut(withDuration: 0.09),
            ]),
            .removeFromParent(),
        ]))
    }

    static func shotWave(at point: CGPoint, color: SKColor, style: WeaponStyle, in parent: SKNode) {
        let baseRadius: CGFloat = style == .heavy ? 10 : 6
        let ring = SKShapeNode(circleOfRadius: baseRadius)
        ring.position = point
        ring.strokeColor = color
        ring.lineWidth = style == .heavy ? 3 : 1.5
        ring.fillColor = .clear
        ring.zPosition = 15
        parent.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: style == .heavy ? 3.2 : 2.2, duration: 0.14),
                .fadeOut(withDuration: 0.14),
            ]),
            .removeFromParent(),
        ]))
    }

    static func decoratePlayerProjectile(_ projectile: SKShapeNode, style: WeaponStyle, color: SKColor) {
        let length: CGFloat
        let width: CGFloat
        switch style {
        case .normal: length = 12; width = 2
        case .heavy: length = 16; width = 6
        case .sniper: length = 30; width = 1.6
        }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -length, y: 0))
        path.addLine(to: .zero)
        let tail = SKShapeNode(path: path)
        tail.strokeColor = color.withAlphaComponent(style == .sniper ? 0.72 : 0.42)
        tail.lineWidth = width
        tail.lineCap = .round
        tail.zPosition = -1
        projectile.addChild(tail)
    }

    // MARK: - Étincelles d'impact

    static func aimTrace(from start: CGPoint, to end: CGPoint, in parent: SKNode) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let trace = SKShapeNode(path: path)
        trace.strokeColor = SKColor(white: 1, alpha: 0.26)
        trace.lineWidth = 1.2
        trace.zPosition = 14
        parent.addChild(trace)
        trace.run(.sequence([
            .fadeOut(withDuration: 0.12),
            .removeFromParent(),
        ]))
    }

    static func impactSparks(at point: CGPoint, color: SKColor, in parent: SKNode, count: Int = 10) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = particleTexture
        emitter.position = point
        emitter.zPosition = 30
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = 400
        emitter.particleLifetime = 0.25
        emitter.particleLifetimeRange = 0.1
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 80
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -3.5
        emitter.particleScale = 0.5
        emitter.particleScaleSpeed = -1.5
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        parent.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
    }

    static func damageNumber(_ amount: CGFloat, at point: CGPoint, color: SKColor, in parent: SKNode) {
        let label = makeLabel("\(Int(amount.rounded()))", size: 17, color: color, font: UIFont2.heavy)
        label.position = point + CGVector(dx: CGFloat.random(in: -6...6), dy: 24)
        label.zPosition = 42
        label.setScale(0.7)
        parent.addChild(label)
        label.run(.sequence([
            .group([
                .scale(to: 1.12, duration: 0.08),
                .moveBy(x: 0, y: 14, duration: 0.18),
            ]),
            .group([
                .scale(to: 0.92, duration: 0.18),
                .moveBy(x: 0, y: 10, duration: 0.18),
                .fadeOut(withDuration: 0.18),
            ]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Poof de mort

    static func deathPoof(at point: CGPoint, color: SKColor, in parent: SKNode) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = particleTexture
        emitter.position = point
        emitter.zPosition = 30
        emitter.numParticlesToEmit = 24
        emitter.particleBirthRate = 800
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.25
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 70
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlphaSpeed = -2
        emitter.particleScale = 0.8
        emitter.particleScaleSpeed = -1.2
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        parent.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))

        // Anneau qui s'étend, façon onde de choc.
        let ring = SKShapeNode(circleOfRadius: 8)
        ring.position = point
        ring.strokeColor = color
        ring.lineWidth = 2.5
        ring.fillColor = .clear
        ring.zPosition = 30
        parent.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 4, duration: 0.35),
                .fadeOut(withDuration: 0.35),
            ]),
            .removeFromParent(),
        ]))
    }


    static func playerKillBurst(at point: CGPoint, color: SKColor, streak: Int, in parent: SKNode) {
        impactSparks(at: point, color: color, in: parent, count: min(46, 24 + streak * 6))
        for index in 0..<2 {
            let ring = SKShapeNode(circleOfRadius: 9)
            ring.position = point
            ring.strokeColor = index == 0 ? .white : color
            ring.lineWidth = index == 0 ? 4 : 2
            ring.fillColor = color.withAlphaComponent(index == 0 ? 0.12 : 0.05)
            ring.zPosition = 38 + CGFloat(index)
            parent.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.035),
                .group([
                    .scale(to: 5.2 + CGFloat(streak) * 0.35, duration: 0.28),
                    .fadeOut(withDuration: 0.28),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}
