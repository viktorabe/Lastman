//
//  GameViewController.swift
//  Lastman iOS
//
//  Created by Viktor Abé on 28/06/2026.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let skView = self.view as! SKView
        // On démarre sur le menu ; les transitions enchaînent vers le match.
        #if DEBUG
        if ProcessInfo.processInfo.environment["LASTMAN_AUTOPLAY"] != nil {
            skView.presentScene(GameScene(size: skView.bounds.size,
                                          difficulty: GameSettings.difficulty,
                                          botCount: GameSettings.botCount))
        } else {
            skView.presentScene(MenuScene.make(size: skView.bounds.size))
        }
        #else
        skView.presentScene(MenuScene.make(size: skView.bounds.size))
        #endif

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // SPEC §4 : portrait sur iPhone (à revalider en playtest).
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
