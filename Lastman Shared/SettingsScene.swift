//
//  SettingsScene.swift
//  Lastman
//
//  Réglages (SPEC §5) : difficulté + nombre de bots, persistés.
//

import SpriteKit

final class SettingsScene: SKScene {

    private let difficultyValue = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let botCountValue = SKLabelNode(fontNamed: "AvenirNext-Bold")

    static func make(size: CGSize) -> SettingsScene {
        let scene = SettingsScene(size: size)
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        size = view.bounds.size
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(white: 0.05, alpha: 1.0)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "RÉGLAGES"
        title.fontSize = 44
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: size.height * 0.30)
        addChild(title)

        // Difficulté
        addRow(label: "Difficulté", y: 90, valueNode: difficultyValue,
               minusName: "diffMinus", plusName: "diffPlus")
        // Nombre de bots
        addRow(label: "Bots", y: -40, valueNode: botCountValue,
               minusName: "botMinus", plusName: "botPlus")

        addChild(UIHelpers.button(text: "RETOUR", name: "back", at: CGPoint(x: 0, y: -size.height * 0.30),
                                  color: Player.signature))

        refresh()
    }

    private func addRow(label: String, y: CGFloat, valueNode: SKLabelNode,
                        minusName: String, plusName: String) {
        let title = SKLabelNode(fontNamed: "AvenirNext-Medium")
        title.text = label
        title.fontSize = 22
        title.fontColor = SKColor(white: 1, alpha: 0.6)
        title.position = CGPoint(x: 0, y: y + 36)
        addChild(title)

        valueNode.fontSize = 28
        valueNode.fontColor = .white
        valueNode.verticalAlignmentMode = .center
        valueNode.position = CGPoint(x: 0, y: y)
        addChild(valueNode)

        addChild(UIHelpers.button(text: "−", name: minusName, at: CGPoint(x: -110, y: y),
                                  color: .white, width: 60, height: 60))
        addChild(UIHelpers.button(text: "+", name: plusName, at: CGPoint(x: 110, y: y),
                                  color: .white, width: 60, height: 60))
    }

    private func refresh() {
        difficultyValue.text = GameSettings.difficulty.title
        botCountValue.text = "\(GameSettings.botCount)"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first,
              let name = UIHelpers.tappedName(at: t.location(in: self), in: self) else { return }
        switch name {
        case "diffMinus": cycleDifficulty(-1)
        case "diffPlus":  cycleDifficulty(1)
        case "botMinus":  GameSettings.botCount = GameSettings.botCount - 1; refresh()
        case "botPlus":   GameSettings.botCount = GameSettings.botCount + 1; refresh()
        case "back":      view?.presentScene(MenuScene.make(size: size), transition: .push(with: .right, duration: 0.4))
        default: break
        }
    }

    private func cycleDifficulty(_ delta: Int) {
        let all = Difficulty.allCases
        let idx = (GameSettings.difficulty.rawValue + delta + all.count) % all.count
        GameSettings.difficulty = all[idx]
        refresh()
    }
}
