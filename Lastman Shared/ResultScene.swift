//
//  ResultScene.swift
//  Lastman
//
//  Écran de fin (SPEC §5) : Victoire / Défaite + rang + Rejouer / Menu.
//

import SpriteKit

final class ResultScene: SKScene {

    private var victory = false
    private var rank = 1
    private var total = 1

    static func make(victory: Bool, rank: Int, total: Int, size: CGSize) -> ResultScene {
        let scene = ResultScene(size: size)
        scene.scaleMode = .resizeFill
        scene.victory = victory
        scene.rank = rank
        scene.total = total
        return scene
    }

    override func didMove(to view: SKView) {
        size = view.bounds.size
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(white: 0.05, alpha: 1.0)

        let headline = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        headline.text = victory ? "VICTOIRE" : "DÉFAITE"
        headline.fontSize = 60
        headline.fontColor = victory ? SKColor(red: 0.4, green: 1, blue: 0.6, alpha: 1) : SKColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        headline.position = CGPoint(x: 0, y: size.height * 0.22)
        addChild(headline)

        let rankLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        rankLabel.text = "Rang  #\(rank) / \(total)"
        rankLabel.fontSize = 30
        rankLabel.fontColor = .white
        rankLabel.position = CGPoint(x: 0, y: size.height * 0.22 - 70)
        addChild(rankLabel)

        addChild(UIHelpers.button(text: "REJOUER", name: "replay", at: CGPoint(x: 0, y: 30),
                                  color: Player.signature))
        addChild(UIHelpers.button(text: "MENU", name: "menu", at: CGPoint(x: 0, y: -70),
                                  color: SKColor(white: 1, alpha: 0.85)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first,
              let name = UIHelpers.tappedName(at: t.location(in: self), in: self) else { return }
        switch name {
        case "replay":
            view?.presentScene(GameScene(size: size, difficulty: GameSettings.difficulty,
                                         botCount: GameSettings.botCount),
                               transition: .doorway(withDuration: 0.6))
        case "menu":
            view?.presentScene(MenuScene.make(size: size), transition: .crossFade(withDuration: 0.4))
        default: break
        }
    }
}
