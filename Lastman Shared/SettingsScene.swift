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
    private var hapticsToggle: ToggleButton!
    private var soundToggle: ToggleButton!
    private var landscapeToggle: ToggleButton!

    static func make(size: CGSize) -> SettingsScene {
        let scene = SettingsScene(size: size)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return scene
    }

    override func didMove(to view: SKView) {
        buildContent()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil else { return }
        buildContent()
    }

    private func buildContent() {
        removeAllChildren()
        difficultyButtons.removeAll()
        backgroundColor = SKColor(white: 0.04, alpha: 1)

        let compact = size.height < 520
        let titleY = compact ? size.height / 2 - 44 : size.height * 0.28
        let difficultyY: CGFloat = compact ? 70 : 110
        let difficultyButtonY: CGFloat = compact ? 32 : 66
        let botsTitleY: CGFloat = compact ? -24 : -10
        let botsY: CGFloat = compact ? -70 : -64
        let landscapeY: CGFloat = compact ? -120 : -118
        let soundY: CGFloat = compact ? -120 : -178
        let hapticsY: CGFloat = compact ? -120 : -238
        let backY: CGFloat = compact ? -178 : -318

        let title = makeLabel("RÉGLAGES", size: 36, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: titleY)
        addChild(title)

        // Difficulté (SPEC §7.4) : le curseur pilote les paramètres des bots.
        let difficultyTitle = makeLabel("Difficulté", size: 18, color: SKColor(white: 1, alpha: 0.6))
        difficultyTitle.position = CGPoint(x: 0, y: difficultyY)
        addChild(difficultyTitle)

        let buttonWidth: CGFloat = 108
        let spacing: CGFloat = 116
        for (index, difficulty) in Difficulty.allCases.enumerated() {
            let button = MenuButton(text: difficulty.label, width: buttonWidth, height: 44, fontSize: 15) { [weak self] in
                self?.select(difficulty)
            }
            button.position = CGPoint(x: CGFloat(index - 1) * spacing, y: difficultyButtonY)
            addChild(button)
            difficultyButtons[difficulty] = button
        }

        // Nombre de bots.
        let botsTitle = makeLabel("Nombre de bots", size: 18, color: SKColor(white: 1, alpha: 0.6))
        botsTitle.position = CGPoint(x: 0, y: botsTitleY)
        addChild(botsTitle)

        let minus = MenuButton(text: "−", width: 56, height: 56, fontSize: 28) { [weak self] in
            GameSettings.botCount -= 1
            Haptics.selectionChanged()
            self?.refresh()
        }
        minus.position = CGPoint(x: -90, y: botsY)
        addChild(minus)

        let plus = MenuButton(text: "+", width: 56, height: 56, fontSize: 28) { [weak self] in
            GameSettings.botCount += 1
            Haptics.selectionChanged()
            self?.refresh()
        }
        plus.position = CGPoint(x: 90, y: botsY)
        addChild(plus)

        botCountLabel = makeLabel("", size: 34, font: UIFont2.heavy)
        botCountLabel.position = CGPoint(x: 0, y: botsY)
        addChild(botCountLabel)

        landscapeToggle = ToggleButton(text: "Paysage", isOn: GameSettings.landscapeModeEnabled) { [weak self] in
            self?.toggleLandscapeMode()
        }
        landscapeToggle.position = compact ? CGPoint(x: -170, y: landscapeY) : CGPoint(x: 0, y: landscapeY)
        landscapeToggle.setScale(compact ? 0.65 : 1)
        addChild(landscapeToggle)

        soundToggle = ToggleButton(text: "Son", isOn: GameSettings.soundEnabled) { [weak self] in
            self?.toggleSound()
        }
        soundToggle.position = compact ? CGPoint(x: 0, y: soundY) : CGPoint(x: 0, y: soundY)
        soundToggle.setScale(compact ? 0.65 : 1)
        addChild(soundToggle)

        hapticsToggle = ToggleButton(text: "Haptique", isOn: GameSettings.hapticsEnabled) { [weak self] in
            self?.toggleHaptics()
        }
        hapticsToggle.position = compact ? CGPoint(x: 170, y: hapticsY) : CGPoint(x: 0, y: hapticsY)
        hapticsToggle.setScale(compact ? 0.65 : 1)
        addChild(hapticsToggle)

        let back = MenuButton(text: "RETOUR") { [weak self] in
            guard let self, let view = self.view else { return }
            view.presentScene(MenuScene.make(size: self.size), transition: .fade(withDuration: 0.3))
        }
        back.position = CGPoint(x: 0, y: backY)
        addChild(back)

        refresh()
    }

    private func select(_ difficulty: Difficulty) {
        GameSettings.difficulty = difficulty
        // La difficulté propose son nombre de bots par défaut (SPEC §7.4),
        // ajustable ensuite avec −/+.
        GameSettings.botCount = difficulty.defaultBotCount
        Haptics.selectionChanged()
        refresh()
    }

    private func toggleHaptics() {
        let isOn = !GameSettings.hapticsEnabled
        GameSettings.hapticsEnabled = isOn
        Haptics.hapticsToggled(isOn: isOn)
        refresh()
    }

    private func toggleSound() {
        GameSettings.soundEnabled.toggle()
        if GameSettings.soundEnabled {
            SoundFX.shared.play(.button)
        }
        refresh()
    }

    private func toggleLandscapeMode() {
        let isOn = !GameSettings.landscapeModeEnabled
        GameSettings.landscapeModeEnabled = isOn
        Haptics.selectionChanged()
        refresh()
    }

    private func refresh() {
        for (difficulty, button) in difficultyButtons {
            button.isHighlighted = difficulty == GameSettings.difficulty
        }
        botCountLabel.text = "\(GameSettings.botCount)"
        landscapeToggle.isOn = GameSettings.landscapeModeEnabled
        soundToggle.isOn = GameSettings.soundEnabled
        hapticsToggle.isOn = GameSettings.hapticsEnabled
    }
}
