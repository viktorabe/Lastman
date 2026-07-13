//
//  MenuScene.swift
//  Lastman
//
//  Écran titre : Jouer / Réglages (SPEC §5).
//

import SpriteKit

final class MenuScene: SKScene {

    private var weaponButtons: [WeaponStyle: MenuButton] = [:]
    private var weaponDetailLabel: SKLabelNode!
    private var footerLabel: SKLabelNode!
    private var profileLabel: SKLabelNode!
    private var dailyDetailLabel: SKLabelNode!
    private var missionLabel: SKLabelNode!
    private var displayedChallenge = DailyChallenge.today

    static func make(size: CGSize) -> MenuScene {
        let scene = MenuScene(size: size)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.04, alpha: 1)
        if let hostingViewController {
            GameCenterManager.shared.authenticate(from: hostingViewController)
        }
        displayedChallenge = ChallengeLinkStore.consumeChallenge() ?? .today
        let compact = size.height < 520

        let title = makeLabel("LASTMAN", size: compact ? 38 : 52, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: compact ? 142 : size.height * 0.27)
        addChild(title)
        title.run(.repeatForever(.sequence([
            .scale(to: 1.03, duration: 1.2),
            .scale(to: 1.0, duration: 1.2),
        ])))

        let subtitle = makeLabel("Battle royale stickman · offline", size: 16,
                                 color: SKColor(white: 1, alpha: 0.6))
        subtitle.position = CGPoint(x: 0, y: title.position.y - (compact ? 34 : 44))
        addChild(subtitle)

        profileLabel = makeLabel("", size: 13, color: SKColor(white: 1, alpha: 0.58), font: UIFont2.bold)
        profileLabel.position = CGPoint(x: 0, y: compact ? 82 : 150)
        addChild(profileLabel)

        let daily = MenuButton(
            text: displayedChallenge.dayKey == DailyChallenge.today.dayKey ? "DÉFI DU JOUR" : "DÉFI REÇU",
            width: compact ? 210 : 270,
            height: compact ? 42 : 52,
            fontSize: compact ? 16 : 19
        ) { [weak self] in
            self?.startDailyChallenge()
        }
        daily.isHighlighted = true
        daily.position = CGPoint(x: 0, y: compact ? 42 : 100)
        addChild(daily)

        dailyDetailLabel = makeLabel("", size: compact ? 11 : 13, color: SKColor(white: 1, alpha: 0.5))
        dailyDetailLabel.position = CGPoint(x: 0, y: compact ? 14 : 62)
        addChild(dailyDetailLabel)

        missionLabel = makeLabel("", size: compact ? 9 : 10,
                                 color: SKColor(red: 0.95, green: 0.86, blue: 0.42, alpha: 0.72),
                                 font: UIFont2.bold)
        missionLabel.position = CGPoint(x: 0, y: compact ? -1 : 38)
        addChild(missionLabel)

        let weaponTitle = makeLabel("Style de tir", size: 17, color: SKColor(white: 1, alpha: 0.62), font: UIFont2.bold)
        weaponTitle.position = CGPoint(x: 0, y: compact ? -18 : 10)
        addChild(weaponTitle)

        let weaponButtonWidth: CGFloat = compact ? 92 : 104
        let weaponSpacing: CGFloat = compact ? 98 : 112
        for (index, style) in WeaponStyle.allCases.enumerated() {
            let button = MenuButton(text: style.menuTitle, width: weaponButtonWidth, height: 46, fontSize: 16) { [weak self] in
                self?.selectWeapon(style)
            }
            button.position = CGPoint(x: CGFloat(index - 1) * weaponSpacing, y: compact ? -54 : -38)
            button.setScale(compact ? 0.88 : 1)
            addChild(button)
            weaponButtons[style] = button
        }

        weaponDetailLabel = makeLabel("", size: 13, color: SKColor(white: 1, alpha: 0.46))
        weaponDetailLabel.position = CGPoint(x: 0, y: compact ? -84 : -77)
        addChild(weaponDetailLabel)

        let playButton = MenuButton(text: "JOUER") { [weak self] in
            self?.startMatch()
        }
        playButton.position = CGPoint(x: 0, y: compact ? -124 : -136)
        playButton.setScale(compact ? 0.82 : 1)
        addChild(playButton)

        let settingsButton = MenuButton(text: "RÉGLAGES") { [weak self] in
            self?.openSettings()
        }
        settingsButton.position = CGPoint(x: compact ? -96 : 0, y: compact ? -174 : -202)
        settingsButton.setScale(compact ? 0.68 : 0.88)
        addChild(settingsButton)

        let leaderboardButton = MenuButton(text: "CLASSEMENT") { [weak self] in
            guard let self else { return }
            GameCenterManager.shared.showLeaderboards(from: self.hostingViewController)
        }
        leaderboardButton.position = CGPoint(x: compact ? 96 : 0, y: compact ? -174 : -260)
        leaderboardButton.setScale(compact ? 0.68 : 0.88)
        addChild(leaderboardButton)

        footerLabel = makeLabel("", size: 14, color: SKColor(white: 1, alpha: 0.4))
        footerLabel.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        footerLabel.alpha = compact ? 0 : 1
        addChild(footerLabel)

        refreshWeaponSelection()
    }

    private func startDailyChallenge() {
        guard let view else { return }
        let challenge = displayedChallenge
        let game = GameScene(
            size: size,
            difficulty: challenge.difficulty,
            botCount: challenge.botCount,
            weaponStyle: challenge.weaponStyle,
            matchMode: .daily(challenge)
        )
        view.presentScene(game, transition: .fade(withDuration: 0.35))
    }

    private func startMatch() {
        guard let view else { return }
        let game = GameScene(size: size,
                             difficulty: GameSettings.difficulty,
                             botCount: GameSettings.botCount,
                             weaponStyle: GameSettings.weaponStyle)
        view.presentScene(game, transition: .fade(withDuration: 0.4))
    }

    private func selectWeapon(_ style: WeaponStyle) {
        GameSettings.weaponStyle = style
        Haptics.selectionChanged()
        refreshWeaponSelection()
    }

    private func refreshWeaponSelection() {
        let selected = GameSettings.weaponStyle
        for (style, button) in weaponButtons {
            button.isHighlighted = style == selected
        }
        weaponDetailLabel.text = selected.menuSubtitle
        footerLabel.text = "\(GameSettings.botCount) bots · \(GameSettings.difficulty.label) · \(selected.label)"
        let profile = ProgressionStore.profile
        profileLabel.text = "NIVEAU \(ProgressionStore.level) · \(profile.dailyStreak) J DE SÉRIE · \(profile.victories) VICTOIRES"
        let best = ProgressionStore.bestScore(for: displayedChallenge.dayKey)
        let bestText = best > 0 ? "record \(best) pts" : "premier essai disponible"
        dailyDetailLabel.text = "\(displayedChallenge.modifier.title.lowercased()) · \(displayedChallenge.weaponStyle.label.lowercased()) · \(bestText)"
        missionLabel.text = ProgressionStore.missionText(for: displayedChallenge.dayKey)
    }

    private func openSettings() {
        guard let view else { return }
        view.presentScene(SettingsScene.make(size: size), transition: .fade(withDuration: 0.3))
    }
}
