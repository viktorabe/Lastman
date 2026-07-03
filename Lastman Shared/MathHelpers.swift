//
//  MathHelpers.swift
//  Lastman
//
//  Petites extensions vecteurs/points + bruit gaussien pour l'aimError.
//

import CoreGraphics
import Foundation

extension CGVector {
    init(from: CGPoint, to: CGPoint) {
        self.init(dx: to.x - from.x, dy: to.y - from.y)
    }

    init(angle: CGFloat, length: CGFloat = 1) {
        self.init(dx: cos(angle) * length, dy: sin(angle) * length)
    }

    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var angle: CGFloat {
        atan2(dy, dx)
    }

    var normalized: CGVector {
        let l = length
        guard l > 0.0001 else { return .zero }
        return CGVector(dx: dx / l, dy: dy / l)
    }

    /// Vecteur perpendiculaire (rotation de +90°).
    var perpendicular: CGVector {
        CGVector(dx: -dy, dy: dx)
    }

    static func + (a: CGVector, b: CGVector) -> CGVector {
        CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy)
    }

    static func - (a: CGVector, b: CGVector) -> CGVector {
        CGVector(dx: a.dx - b.dx, dy: a.dy - b.dy)
    }

    static func * (v: CGVector, s: CGFloat) -> CGVector {
        CGVector(dx: v.dx * s, dy: v.dy * s)
    }

    /// Interpolation linéaire vers `target` (t clampé à [0, 1]).
    func lerped(to target: CGVector, t: CGFloat) -> CGVector {
        let k = min(max(t, 0), 1)
        return CGVector(dx: dx + (target.dx - dx) * k, dy: dy + (target.dy - dy) * k)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }

    static func + (p: CGPoint, v: CGVector) -> CGPoint {
        CGPoint(x: p.x + v.dx, y: p.y + v.dy)
    }
}

/// Bruit gaussien (Box-Muller). Utilisé pour l'aimError des bots (SPEC §7.4).
func gaussianRandom(mean: CGFloat = 0, stdDev: CGFloat = 1) -> CGFloat {
    let u1 = CGFloat.random(in: 0.0001...1)
    let u2 = CGFloat.random(in: 0...1)
    let z = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    return mean + z * stdDev
}

extension CGFloat {
    var degreesToRadians: CGFloat { self * .pi / 180 }
}
