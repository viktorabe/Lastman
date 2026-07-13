//
//  ResultScene.swift
//  Lastman
//
//  Victoire / Défaite avec rang, Rejouer / Menu (SPEC §5).
//

import SpriteKit

final class ResultScene: SKScene {

    private let summary: MatchSummary

    init(size: CGSize, summary: MatchSummary) {
        self.summary = summary
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.04, alpha: 1)
        let compact = size.height < 520
        let titleY = compact ? size.height / 2 - 48 : size.height * 0.2
        let statStartY = compact ? titleY - 114 : titleY - 138
        let statGap: CGFloat = compact ? 22 : 24
        let replayY: CGFloat = compact ? -90 : -112
        let menuY: CGFloat = compact ? -150 : -184

        let titleColor: SKColor = summary.victory
            ? SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1)
            : SKColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1)
        let title = makeLabel(summary.victory ? "VICTOIRE" : "DÉFAITE", size: 46, color: titleColor, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: titleY)
        title.setScale(0.3)
        title.alpha = 0
        addChild(title)
        title.run(.group([
            .scale(to: 1, duration: 0.35),
            .fadeIn(withDuration: 0.25),
        ]))

        let rankLabel = makeLabel("#\(summary.rank) sur \(summary.total)", size: 26, font: UIFont2.bold)
        rankLabel.position = CGPoint(x: 0, y: titleY - 54)
        addChild(rankLabel)

        let subtitle = makeLabel(summary.deathCause, size: 16,
                                 color: SKColor(white: 1, alpha: 0.5))
        subtitle.position = CGPoint(x: 0, y: titleY - 92)
        addChild(subtitle)

        let bestPrefix = summary.isNewBestSurvival ? "Nouveau record" : "Record"
        let lines = [
            "Survie \(formatDuration(summary.survivalTime)) · \(bestPrefix) \(formatDuration(summary.bestSurvivalTime))",
            "\(summary.playerKills) kills · \(summary.playerDamageDealt) dégâts infligés",
            "\(summary.playerDamageTaken) dégâts reçus · \(summary.playerPickupsCollected) bonus",
            "Meilleure série x\(summary.bestKillStreak) · \(summary.playerBreakablesDestroyed) caisses",
        ]
        for (index, line) in lines.enumerated() {
            let stat = makeLabel(line, size: 15, color: SKColor(white: 1, alpha: 0.64), font: UIFont2.bold)
            stat.position = CGPoint(x: 0, y: statStartY - CGFloat(index) * statGap)
            addChild(stat)
        }

        let replay = MenuButton(text: "REJOUER") { [weak self] in
            guard let self, let view = self.view else { return }
            let game = GameScene(size: self.size,
                                 difficulty: GameSettings.difficulty,
                                 botCount: GameSettings.botCount,
                                 weaponStyle: GameSettings.weaponStyle,
                                 quickStart: true)
            view.presentScene(game, transition: .crossFade(withDuration: 0.18))
        }
        replay.position = CGPoint(x: 0, y: replayY)
        addChild(replay)

        let menu = MenuButton(text: "MENU") { [weak self] in
            guard let self, let view = self.view else { return }
            view.presentScene(MenuScene.make(size: self.size), transition: .fade(withDuration: 0.3))
        }
        menu.position = CGPoint(x: 0, y: menuY)
        addChild(menu)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let total = max(0, Int(time.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
