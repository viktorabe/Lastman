//
//  UIHelpers.swift
//  Lastman
//
//  Boutons et labels des écrans méta (menu, réglages, résultat).
//

import SpriteKit

enum UIFont2 {
    static let heavy = "AvenirNext-Heavy"
    static let bold = "AvenirNext-Bold"
    static let medium = "AvenirNext-Medium"
}

func makeLabel(_ text: String, size: CGFloat, color: SKColor = .white, font: String = UIFont2.medium) -> SKLabelNode {
    let label = SKLabelNode(fontNamed: font)
    label.text = text
    label.fontSize = size
    label.fontColor = color
    label.verticalAlignmentMode = .center
    return label
}

final class MenuButton: SKNode {

    private let background: SKShapeNode
    private let label: SKLabelNode
    private let action: () -> Void

    var isHighlighted = false {
        didSet {
            background.strokeColor = isHighlighted ? .white : SKColor(white: 1, alpha: 0.4)
            background.fillColor = isHighlighted ? SKColor(white: 1, alpha: 0.18) : SKColor(white: 1, alpha: 0.05)
            background.lineWidth = isHighlighted ? 2.5 : 1.5
        }
    }

    init(text: String, width: CGFloat = 240, height: CGFloat = 54, fontSize: CGFloat = 21, action: @escaping () -> Void) {
        self.action = action
        background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        background.fillColor = SKColor(white: 1, alpha: 0.05)
        background.strokeColor = SKColor(white: 1, alpha: 0.4)
        background.lineWidth = 1.5

        label = makeLabel(text, size: fontSize, font: UIFont2.bold)

        super.init()
        addChild(background)
        addChild(label)
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 0.92, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1, duration: 0.08))
        guard let touch = touches.first, let parent else { return }
        let p = touch.location(in: parent)
        if calculateAccumulatedFrame().contains(p) {
            Haptics.buttonTap()
            action()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1, duration: 0.08))
    }
}

final class ToggleButton: SKNode {

    private let track: SKShapeNode
    private let knob: SKShapeNode
    private let label: SKLabelNode
    private let width: CGFloat
    private let action: () -> Void

    var isOn = true {
        didSet {
            refresh()
        }
    }

    init(text: String, width: CGFloat = 240, height: CGFloat = 54, isOn: Bool, action: @escaping () -> Void) {
        self.width = width
        self.action = action
        track = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height / 2)
        knob = SKShapeNode(circleOfRadius: height * 0.34)
        label = makeLabel(text, size: 18, font: UIFont2.bold)
        self.isOn = isOn

        super.init()

        addChild(track)
        addChild(label)
        addChild(knob)
        isUserInteractionEnabled = true
        refresh()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func refresh() {
        track.fillColor = isOn
            ? SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 0.28)
            : SKColor(white: 1, alpha: 0.05)
        track.strokeColor = isOn
            ? SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1)
            : SKColor(white: 1, alpha: 0.4)
        track.lineWidth = isOn ? 2.5 : 1.5
        knob.fillColor = isOn ? .white : SKColor(white: 1, alpha: 0.45)
        knob.strokeColor = .clear
        knob.position = CGPoint(x: isOn ? width / 2 - 28 : -width / 2 + 28, y: 0)
        label.text = "\(label.text?.components(separatedBy: " · ").first ?? "") · \(isOn ? "ON" : "OFF")"
        label.fontColor = isOn ? .white : SKColor(white: 1, alpha: 0.6)
        label.position = CGPoint(x: -24, y: 0)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 0.96, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1, duration: 0.08))
        guard let touch = touches.first, let parent else { return }
        let p = touch.location(in: parent)
        if calculateAccumulatedFrame().contains(p) {
            action()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1, duration: 0.08))
    }
}
