//
//  MathHelpers.swift
//  Lastman
//
//  Petits helpers vectoriels (déplacement, visée, steering) et bruit gaussien
//  (pour `aimError`, cf. SPEC §7.4).
//

import CoreGraphics
import Foundation

extension CGVector {
    var length: CGFloat { hypot(dx, dy) }
    var angle: CGFloat { atan2(dy, dx) }

    init(angle: CGFloat) { self.init(dx: cos(angle), dy: sin(angle)) }

    func normalized() -> CGVector {
        let l = length
        return l > 0 ? CGVector(dx: dx / l, dy: dy / l) : .zero
    }

    /// Bornée à une longueur maximale de 1.
    func clampedToUnit() -> CGVector {
        let l = length
        return l > 1 ? CGVector(dx: dx / l, dy: dy / l) : self
    }

    static func * (v: CGVector, s: CGFloat) -> CGVector { CGVector(dx: v.dx * s, dy: v.dy * s) }
    static func + (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy) }
    static func - (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx - b.dx, dy: a.dy - b.dy) }
}

extension CGPoint {
    static func - (a: CGPoint, b: CGPoint) -> CGVector { CGVector(dx: a.x - b.x, dy: a.y - b.y) }
    static func + (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x + v.dx, y: p.y + v.dy) }

    func distance(to p: CGPoint) -> CGFloat { hypot(p.x - x, p.y - y) }
}

enum RandomMath {
    /// Bruit gaussien (Box-Muller). Sert à brouiller l'angle de tir des bots.
    static func gaussian(mean: CGFloat = 0, sd: CGFloat = 1) -> CGFloat {
        let u1 = max(CGFloat.random(in: 0...1), 1e-9)
        let u2 = CGFloat.random(in: 0...1)
        let z = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
        return mean + z * sd
    }
}
