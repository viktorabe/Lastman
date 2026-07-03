//
//  SettingsScene.swift
//  Lastman
//
//  Réglages : nombre de bots + difficulté, persistés (SPEC §5).
//

import SpriteKit

final class SettingsScene: SKScene {

    private var difficultyButtons: [Difficulty: MenuButton] = [:]
    private var botCountLabel: SKLabelNode!

    static func make(size: CGSize) -> SettingsScene {
        let scene = SettingsScene(size: size)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.04, alpha: 1)

        let title = makeLabel("RÉGLAGES", size: 36, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: size.height * 0.28)
        addChild(title)

        // Difficulté (SPEC §7.4) : le curseur pilote les paramètres des bots.
        let difficultyTitle = makeLabel("Difficulté", size: 18, color: SKColor(white: 1, alpha: 0.6))
        difficultyTitle.position = CGPoint(x: 0, y: 110)
        addChild(difficultyTitle)

        let buttonWidth: CGFloat = 108
        let spacing: CGFloat = 116
        for (index, difficulty) in Difficulty.allCases.enumerated() {
            let button = MenuButton(text: difficulty.label, width: buttonWidth, height: 44, fontSize: 15) { [weak self] in
                self?.select(difficulty)
            }
            button.position = CGPoint(x: CGFloat(index - 1) * spacing, y: 66)
            addChild(button)
            difficultyButtons[difficulty] = button
        }

        // Nombre de bots.
        let botsTitle = makeLabel("Nombre de bots", size: 18, color: SKColor(white: 1, alpha: 0.6))
        botsTitle.position = CGPoint(x: 0, y: -10)
        addChild(botsTitle)

        let minus = MenuButton(text: "−", width: 56, height: 56, fontSize: 28) { [weak self] in
            GameSettings.botCount -= 1
            self?.refresh()
        }
        minus.position = CGPoint(x: -90, y: -64)
        addChild(minus)

        let plus = MenuButton(text: "+", width: 56, height: 56, fontSize: 28) { [weak self] in
            GameSettings.botCount += 1
            self?.refresh()
        }
        plus.position = CGPoint(x: 90, y: -64)
        addChild(plus)

        botCountLabel = makeLabel("", size: 34, font: UIFont2.heavy)
        botCountLabel.position = CGPoint(x: 0, y: -64)
        addChild(botCountLabel)

        let back = MenuButton(text: "RETOUR") { [weak self] in
            guard let self, let view = self.view else { return }
            view.presentScene(MenuScene.make(size: self.size), transition: .fade(withDuration: 0.3))
        }
        back.position = CGPoint(x: 0, y: -170)
        addChild(back)

        refresh()
    }

    private func select(_ difficulty: Difficulty) {
        GameSettings.difficulty = difficulty
        // La difficulté propose son nombre de bots par défaut (SPEC §7.4),
        // ajustable ensuite avec −/+.
        GameSettings.botCount = difficulty.defaultBotCount
        refresh()
    }

    private func refresh() {
        for (difficulty, button) in difficultyButtons {
            button.isHighlighted = difficulty == GameSettings.difficulty
        }
        botCountLabel.text = "\(GameSettings.botCount)"
    }
}
