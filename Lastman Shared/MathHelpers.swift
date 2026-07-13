//
//  MathHelpers.swift
//  Lastman
//
//  Petites extensions vecteurs/points.
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
