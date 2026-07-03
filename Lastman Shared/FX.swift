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

    static func muzzleFlash(at point: CGPoint, angle: CGFloat, in parent: SKNode) {
        let flash = SKShapeNode(circleOfRadius: 5)
        flash.position = point
        flash.zRotation = angle
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.zPosition = 16
        flash.xScale = 1.6
        parent.addChild(flash)
        flash.run(.sequence([
            .group([
                .scale(to: 0.2, duration: 0.09),
                .fadeOut(withDuration: 0.09),
            ]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Étincelles d'impact

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
}
