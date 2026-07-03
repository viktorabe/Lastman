//
//  MenuScene.swift
//  Lastman
//
//  Écran titre : Jouer / Réglages (SPEC §5).
//

import SpriteKit

final class MenuScene: SKScene {

    static func make(size: CGSize) -> MenuScene {
        let scene = MenuScene(size: size)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.04, alpha: 1)

        let title = makeLabel("LASTMAN", size: 52, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: size.height * 0.22)
        addChild(title)
        title.run(.repeatForever(.sequence([
            .scale(to: 1.03, duration: 1.2),
            .scale(to: 1.0, duration: 1.2),
        ])))

        let subtitle = makeLabel("Battle royale stickman · offline", size: 16,
                                 color: SKColor(white: 1, alpha: 0.6))
        subtitle.position = CGPoint(x: 0, y: size.height * 0.22 - 44)
        addChild(subtitle)

        let playButton = MenuButton(text: "JOUER") { [weak self] in
            self?.startMatch()
        }
        playButton.position = CGPoint(x: 0, y: -20)
        addChild(playButton)

        let settingsButton = MenuButton(text: "RÉGLAGES") { [weak self] in
            self?.openSettings()
        }
        settingsButton.position = CGPoint(x: 0, y: -94)
        addChild(settingsButton)

        let footer = makeLabel("\(GameSettings.botCount) bots · \(GameSettings.difficulty.label)", size: 14,
                               color: SKColor(white: 1, alpha: 0.4))
        footer.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        addChild(footer)
    }

    private func startMatch() {
        guard let view else { return }
        let game = GameScene(size: size,
                             difficulty: GameSettings.difficulty,
                             botCount: GameSettings.botCount)
        view.presentScene(game, transition: .fade(withDuration: 0.4))
    }

    private func openSettings() {
        guard let view else { return }
        view.presentScene(SettingsScene.make(size: size), transition: .fade(withDuration: 0.3))
    }
}
