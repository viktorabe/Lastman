//
//  ResultScene.swift
//  Lastman
//
//  Victoire / Défaite avec rang, Rejouer / Menu (SPEC §5).
//

import SpriteKit

final class ResultScene: SKScene {

    private let victory: Bool
    private let rank: Int
    private let total: Int

    init(size: CGSize, victory: Bool, rank: Int, total: Int) {
        self.victory = victory
        self.rank = rank
        self.total = total
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.04, alpha: 1)

        let titleColor: SKColor = victory
            ? SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1)
            : SKColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1)
        let title = makeLabel(victory ? "VICTOIRE" : "DÉFAITE", size: 46, color: titleColor, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: size.height * 0.2)
        title.setScale(0.3)
        title.alpha = 0
        addChild(title)
        title.run(.group([
            .scale(to: 1, duration: 0.35),
            .fadeIn(withDuration: 0.25),
        ]))

        let rankLabel = makeLabel("#\(rank) sur \(total)", size: 26, font: UIFont2.bold)
        rankLabel.position = CGPoint(x: 0, y: size.height * 0.2 - 54)
        addChild(rankLabel)

        let subtitle = makeLabel(victory ? "Dernier debout." : "Un bot a été plus malin.", size: 16,
                                 color: SKColor(white: 1, alpha: 0.5))
        subtitle.position = CGPoint(x: 0, y: size.height * 0.2 - 92)
        addChild(subtitle)

        let replay = MenuButton(text: "REJOUER") { [weak self] in
            guard let self, let view = self.view else { return }
            let game = GameScene(size: self.size,
                                 difficulty: GameSettings.difficulty,
                                 botCount: GameSettings.botCount)
            view.presentScene(game, transition: .fade(withDuration: 0.4))
        }
        replay.position = CGPoint(x: 0, y: -40)
        addChild(replay)

        let menu = MenuButton(text: "MENU") { [weak self] in
            guard let self, let view = self.view else { return }
            view.presentScene(MenuScene.make(size: self.size), transition: .fade(withDuration: 0.3))
        }
        menu.position = CGPoint(x: 0, y: -114)
        addChild(menu)
    }
}
