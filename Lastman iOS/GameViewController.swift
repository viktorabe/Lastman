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
        let environment = ProcessInfo.processInfo.environment
        let isScreenshotRun = environment["LASTMAN_SCREENSHOT"] != nil
        // On démarre sur le menu ; les transitions enchaînent vers le match.
        #if DEBUG
        if environment["LASTMAN_SCREENSHOT_RESULT"] != nil {
            var summary = MatchSummary(
                victory: true,
                rank: 1,
                total: 8,
                survivalTime: 87,
                bestSurvivalTime: 87,
                isNewBestSurvival: true,
                playerKills: 5,
                playerDamageDealt: 428,
                playerDamageTaken: 64,
                playerPickupsCollected: 4,
                playerBreakablesDestroyed: 6,
                bestKillStreak: 3,
                deathCause: "Dernier debout.",
                matchMode: .daily(.today),
                weaponStyle: .sniper,
                score: 9_420
            )
            summary.xpEarned = 315
            summary.progressionLevel = 4
            summary.didLevelUp = true
            summary.isNewDailyBest = true
            skView.presentScene(ResultScene(size: skView.bounds.size, summary: summary))
        } else if environment["LASTMAN_SCREENSHOT_DAILY"] != nil {
            let challenge = DailyChallenge.today
            skView.presentScene(GameScene(
                size: skView.bounds.size,
                difficulty: .easy,
                botCount: 1,
                weaponStyle: challenge.weaponStyle,
                matchMode: .daily(challenge)
            ))
        } else if environment["LASTMAN_AUTOPLAY"] != nil {
            skView.presentScene(GameScene(size: skView.bounds.size,
                                          difficulty: GameSettings.difficulty,
                                          botCount: GameSettings.botCount,
                                          weaponStyle: GameSettings.weaponStyle))
        } else {
            presentInitialScene(in: skView)
        }
        #else
        presentInitialScene(in: skView)
        #endif

        skView.ignoresSiblingOrder = true
        #if DEBUG
        skView.showsFPS = !isScreenshotRun
        skView.showsNodeCount = !isScreenshotRun
        #else
        skView.showsFPS = false
        skView.showsNodeCount = false
        #endif
        applyOrientationPreference()
    }

    private func presentInitialScene(in skView: SKView) {
        if ProgressionStore.hasCompletedFirstMatch {
            skView.presentScene(MenuScene.make(size: skView.bounds.size))
        } else {
            let tutorial = GameScene(
                size: skView.bounds.size,
                difficulty: .easy,
                botCount: 3,
                weaponStyle: .normal,
                matchMode: .tutorial
            )
            skView.presentScene(tutorial)
        }
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
