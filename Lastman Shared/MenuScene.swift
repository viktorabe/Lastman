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

        let weaponTitle = makeLabel("Style de tir", size: 17, color: SKColor(white: 1, alpha: 0.62), font: UIFont2.bold)
        weaponTitle.position = CGPoint(x: 0, y: 52)
        addChild(weaponTitle)

        let weaponButtonWidth: CGFloat = 104
        let weaponSpacing: CGFloat = 112
        for (index, style) in WeaponStyle.allCases.enumerated() {
            let button = MenuButton(text: style.menuTitle, width: weaponButtonWidth, height: 46, fontSize: 16) { [weak self] in
                self?.selectWeapon(style)
            }
            button.position = CGPoint(x: CGFloat(index - 1) * weaponSpacing, y: 4)
            addChild(button)
            weaponButtons[style] = button
        }

        weaponDetailLabel = makeLabel("", size: 13, color: SKColor(white: 1, alpha: 0.46))
        weaponDetailLabel.position = CGPoint(x: 0, y: -35)
        addChild(weaponDetailLabel)

        let playButton = MenuButton(text: "JOUER") { [weak self] in
            self?.startMatch()
        }
        playButton.position = CGPoint(x: 0, y: -104)
        addChild(playButton)

        let settingsButton = MenuButton(text: "RÉGLAGES") { [weak self] in
            self?.openSettings()
        }
        settingsButton.position = CGPoint(x: 0, y: -174)
        addChild(settingsButton)

        footerLabel = makeLabel("", size: 14, color: SKColor(white: 1, alpha: 0.4))
        footerLabel.position = CGPoint(x: 0, y: -size.height / 2 + 40)
        addChild(footerLabel)

        refreshWeaponSelection()
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
    }

    private func openSettings() {
        guard let view else { return }
        view.presentScene(SettingsScene.make(size: size), transition: .fade(withDuration: 0.3))
    }
}
