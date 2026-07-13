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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applyOrientationPreference),
                                               name: GameSettings.orientationPreferenceDidChange,
                                               object: nil)
        
        let skView = self.view as! SKView
        // On démarre sur le menu ; les transitions enchaînent vers le match.
        #if DEBUG
        if ProcessInfo.processInfo.environment["LASTMAN_AUTOPLAY"] != nil {
            skView.presentScene(GameScene(size: skView.bounds.size,
                                          difficulty: GameSettings.difficulty,
                                          botCount: GameSettings.botCount,
                                          weaponStyle: GameSettings.weaponStyle))
        } else {
            skView.presentScene(MenuScene.make(size: skView.bounds.size))
        }
        #else
        skView.presentScene(MenuScene.make(size: skView.bounds.size))
        #endif

        skView.ignoresSiblingOrder = true
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #else
        skView.showsFPS = false
        skView.showsNodeCount = false
        #endif
        applyOrientationPreference()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyOrientationPreference()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return GameSettings.landscapeModeEnabled ? .landscape : .portrait
        } else {
            return GameSettings.landscapeModeEnabled ? .landscape : .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    @objc private func applyOrientationPreference() {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        guard let windowScene = view.window?.windowScene else { return }
        let mask = supportedInterfaceOrientations
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }
}
