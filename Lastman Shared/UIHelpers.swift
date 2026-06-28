//
//  UIHelpers.swift
//  Lastman
//
//  Fabrique de boutons pour les écrans du shell (menu / réglages / résultat).
//  Le `name` est posé sur les sous-nodes géométriques pour la détection au tap.
//

import SpriteKit

enum UIHelpers {

    static func button(text: String, name: String, at position: CGPoint,
                       color: SKColor, width: CGFloat = 260, height: CGFloat = 64) -> SKNode {
        let container = SKNode()
        container.position = position
        container.name = name

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 14)
        bg.fillColor = SKColor(white: 1, alpha: 0.08)
        bg.strokeColor = color
        bg.lineWidth = 2.5
        bg.name = name
        container.addChild(bg)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 24
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        container.addChild(label)

        return container
    }

    /// Renvoie le `name` du premier node nommé sous le point touché.
    static func tappedName(at point: CGPoint, in scene: SKScene) -> String? {
        scene.nodes(at: point).first(where: { $0.name != nil })?.name
    }
}
