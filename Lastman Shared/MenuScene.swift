//
//  MenuScene.swift
//  Lastman
//
//  Écran titre (SPEC §5) : Jouer / Réglages.
//

import SpriteKit

final class MenuScene: SKScene {

    static func make(size: CGSize) -> MenuScene {
        let scene = MenuScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        size = view.bounds.size
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(white: 0.05, alpha: 1.0)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "LASTMAN"
        title.fontSize = 64
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: size.height * 0.22)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "Battle Royale"
        subtitle.fontSize = 22
        subtitle.fontColor = SKColor(white: 1, alpha: 0.5)
        subtitle.position = CGPoint(x: 0, y: size.height * 0.22 - 48)
        addChild(subtitle)

        addChild(UIHelpers.button(text: "JOUER", name: "play", at: CGPoint(x: 0, y: 40),
                                  color: Player.signature))
        addChild(UIHelpers.button(text: "RÉGLAGES", name: "settings", at: CGPoint(x: 0, y: -60),
                                  color: SKColor(white: 1, alpha: 0.85)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let tapped = nodes(at: t.location(in: self)).compactMap { $0.name }
        if tapped.contains("play") {
            view?.presentScene(GameScene(size: size, difficulty: GameSettings.difficulty,
                                         botCount: GameSettings.botCount),
                               transition: .doorway(withDuration: 0.6))
        } else if tapped.contains("settings") {
            view?.presentScene(SettingsScene.make(size: size), transition: .push(with: .left, duration: 0.4))
        }
    }
}
