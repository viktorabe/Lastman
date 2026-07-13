//
//  Haptics.swift
//  Lastman
//
//  Retour tactile centralise, desactive via les reglages.
//

import UIKit

enum Haptics {
    private static var lastPulseAt: TimeInterval = 0

    static func buttonTap() {
        impact(.light, intensity: 0.65)
    }

    static func selectionChanged() {
        guard GameSettings.hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func hapticsToggled(isOn: Bool) {
        notification(isOn ? .success : .warning, ignoringPreference: true)
    }

    static func joystickStarted() {
        throttledImpact(.light, intensity: 0.45, minimumDelay: 0.2)
    }

    static func countdownTick() {
        impact(.soft, intensity: 0.75)
    }

    static func matchStarted() {
        impact(.rigid, intensity: 0.95)
    }

    static func playerShot(style: WeaponStyle = .normal) {
        switch style {
        case .normal:
            throttledImpact(.light, intensity: 0.35, minimumDelay: 0.12)
        case .heavy:
            throttledImpact(.heavy, intensity: 0.65, minimumDelay: 0.18)
        case .sniper:
            throttledImpact(.rigid, intensity: 0.45, minimumDelay: 0.22)
        }
    }

    static func hitLanded() {
        throttledImpact(.medium, intensity: 0.55, minimumDelay: 0.1)
    }

    static func playerKill(streak: Int) {
        if streak >= 3 {
            notification(.success)
        } else {
            impact(.rigid, intensity: streak == 2 ? 1.0 : 0.78)
        }
    }

    static func playerDamaged() {
        throttledImpact(.heavy, intensity: 0.85, minimumDelay: 0.18)
    }

    static func playerEliminated() {
        notification(.error)
    }

    static func victory() {
        notification(.success)
    }

    static func defeat() {
        notification(.error)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1) {
        guard GameSettings.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    private static func throttledImpact(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat = 1,
        minimumDelay: TimeInterval
    ) {
        guard GameSettings.hapticsEnabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastPulseAt >= minimumDelay else { return }
        lastPulseAt = now
        impact(style, intensity: intensity)
    }

    private static func notification(
        _ type: UINotificationFeedbackGenerator.FeedbackType,
        ignoringPreference: Bool = false
    ) {
        guard ignoringPreference || GameSettings.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
