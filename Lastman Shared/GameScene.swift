//
//  GameScene.swift
//  Lastman
//
//  Le match : arène fixe, caméra qui suit le joueur, HUD, countdown → active
//  → ended (SPEC §5). Orchestration des systèmes, l'état vit dans GameState.
//

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate, BotWorld {

    private let difficulty: Difficulty
    private let botCount: Int

    private let state = GameState()
    private let worldLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hud = SKNode()

    private var input: InputController!
    private var playerController: PlayerController!
    private var combat: CombatSystem!
    private var zoneImpl: ZoneSystem!
    private var bushImpl: BushSystem!
    var zone: ZoneSystem { zoneImpl }
    var bushSystem: BushSystem { bushImpl }
    private var brains: [BotBrain] = []

    private var lastUpdateTime: TimeInterval = 0
    private var currentGameTime: TimeInterval = 0
    private var shakeAmount: CGFloat = 0

    // HUD
    private var hpBarFill: SKShapeNode!
    private var aliveLabel: SKLabelNode!
    private var zoneLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!
    private var poisonVignette: SKShapeNode!

    // MARK: - Init

    init(size: CGSize, difficulty: Difficulty, botCount: Int) {
        self.difficulty = difficulty
        self.botCount = max(1, botCount)
        super.init(size: size)
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.04, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(worldLayer)
        buildArena()
        buildBushes()
        buildZone()
        spawnCharacters()
        buildCameraAndHUD()

        combat = CombatSystem(worldLayer: worldLayer)
        combat.onImpactShake = { [weak self] amount in
            self?.addShake(amount)
        }

        startCountdown()
    }

    private var arenaRect: CGRect {
        CGRect(origin: .zero, size: GameConfig.arenaSize)
    }

    private func buildArena() {
        // Sol + repères de grille discrets (référence de mouvement pour l'œil).
        let floor = SKShapeNode(rect: arenaRect)
        floor.fillColor = SKColor(white: 0.09, alpha: 1)
        floor.strokeColor = .clear
        floor.zPosition = 0
        worldLayer.addChild(floor)

        let grid = CGMutablePath()
        let step: CGFloat = 200
        var x = step
        while x < arenaRect.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: arenaRect.height))
            x += step
        }
        var y = step
        while y < arenaRect.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: arenaRect.width, y: y))
            y += step
        }
        let gridNode = SKShapeNode(path: grid)
        gridNode.strokeColor = SKColor(white: 1, alpha: 0.045)
        gridNode.lineWidth = 1
        gridNode.zPosition = 1
        worldLayer.addChild(gridNode)

        // Murs extérieurs : bord physique + trait blanc.
        let borderNode = SKShapeNode(rect: arenaRect)
        borderNode.fillColor = .clear
        borderNode.strokeColor = .white
        borderNode.lineWidth = 5
        borderNode.zPosition = 22
        worldLayer.addChild(borderNode)

        let edge = SKNode()
        let edgeBody = SKPhysicsBody(edgeLoopFrom: arenaRect)
        edgeBody.categoryBitMask = PhysicsCategory.wall
        edgeBody.friction = 0
        edge.physicsBody = edgeBody
        worldLayer.addChild(edge)

        // Obstacles intérieurs, layout fixe (SPEC §2 : pas de procédural).
        let obstacles: [(center: CGPoint, size: CGSize)] = [
            (CGPoint(x: 300, y: 420), CGSize(width: 220, height: 36)),
            (CGPoint(x: 900, y: 420), CGSize(width: 220, height: 36)),
            (CGPoint(x: 600, y: 800), CGSize(width: 90, height: 90)),
            (CGPoint(x: 180, y: 850), CGSize(width: 36, height: 260)),
            (CGPoint(x: 1020, y: 850), CGSize(width: 36, height: 260)),
            (CGPoint(x: 420, y: 1180), CGSize(width: 220, height: 36)),
            (CGPoint(x: 800, y: 1250), CGSize(width: 36, height: 220)),
        ]
        for spec in obstacles {
            let block = SKShapeNode(rectOf: spec.size, cornerRadius: 4)
            block.position = spec.center
            block.fillColor = SKColor(white: 0.16, alpha: 1)
            block.strokeColor = SKColor(white: 1, alpha: 0.8)
            block.lineWidth = 2
            block.zPosition = 2

            let body = SKPhysicsBody(rectangleOf: spec.size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.wall
            body.friction = 0
            block.physicsBody = body
            worldLayer.addChild(block)
        }
    }

    private func buildBushes() {
        let layout: [(center: CGPoint, radii: CGSize)] = [
            (CGPoint(x: 170, y: 260), CGSize(width: 85, height: 62)),
            (CGPoint(x: 1030, y: 300), CGSize(width: 85, height: 62)),
            (CGPoint(x: 600, y: 560), CGSize(width: 95, height: 68)),
            (CGPoint(x: 420, y: 1010), CGSize(width: 80, height: 60)),
            (CGPoint(x: 880, y: 1080), CGSize(width: 80, height: 60)),
            (CGPoint(x: 150, y: 1300), CGSize(width: 85, height: 62)),
            (CGPoint(x: 1050, y: 1360), CGSize(width: 85, height: 62)),
        ]
        bushImpl = BushSystem(layout: layout, parent: worldLayer)
    }

    private func buildZone() {
        // Centre légèrement aléatoire autour du centre d'arène (SPEC §6.4).
        let center = CGPoint(
            x: arenaRect.midX + .random(in: -80...80),
            y: arenaRect.midY + .random(in: -80...80)
        )
        // Rayon initial couvrant toute l'arène depuis le centre choisi.
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: arenaRect.maxX, y: 0),
            CGPoint(x: 0, y: arenaRect.maxY),
            CGPoint(x: arenaRect.maxX, y: arenaRect.maxY),
        ]
        let initialRadius = corners.map { $0.distance(to: center) }.max() ?? 1000
        zoneImpl = ZoneSystem(center: center, initialRadius: initialRadius,
                              parent: worldLayer, arenaSize: GameConfig.arenaSize)
    }

    private func spawnCharacters() {
        let playerColor = SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1)
        let player = Character(name: "Toi", isPlayer: true, color: playerColor,
                               position: CGPoint(x: 600, y: 180))
        state.addPlayer(player)
        worldLayer.addChild(player.node)

        let botSpawns: [CGPoint] = [
            CGPoint(x: 140, y: 140), CGPoint(x: 1060, y: 140),
            CGPoint(x: 90, y: 820), CGPoint(x: 1110, y: 820),
            CGPoint(x: 140, y: 1460), CGPoint(x: 1060, y: 1460),
            CGPoint(x: 600, y: 1480), CGPoint(x: 340, y: 1460),
            CGPoint(x: 860, y: 140),
        ]
        for i in 0..<min(botCount, botSpawns.count) {
            let hue = (CGFloat(i) * 0.11 + 0.98).truncatingRemainder(dividingBy: 1)
            let color = SKColor(hue: hue, saturation: 0.6, brightness: 0.95, alpha: 1)
            let bot = Character(name: "Bot \(i + 1)", isPlayer: false, color: color,
                                position: botSpawns[i])
            state.addBot(bot)
            worldLayer.addChild(bot.node)
            brains.append(BotBrain(bot: bot, world: self, difficulty: difficulty))
        }

        for character in state.characters {
            character.onDeath = { [weak self] dead in
                self?.handleDeath(of: dead)
            }
        }
    }

    private func buildCameraAndHUD() {
        cameraNode.position = state.player.position
        cameraNode.setScale(GameConfig.cameraZoom)
        addChild(cameraNode)
        camera = cameraNode

        // Les enfants de la caméra sont rendus en points écran (le transform
        // de la caméra s'annule) : positions HUD = coordonnées écran.
        hud.zPosition = 100
        cameraNode.addChild(hud)

        let w = size.width
        let h = size.height

        // Vignette rouge quand le joueur prend du poison hors zone.
        poisonVignette = SKShapeNode(rectOf: CGSize(width: w * 1.2, height: h * 1.2))
        poisonVignette.fillColor = SKColor(red: 0.8, green: 0.1, blue: 0.15, alpha: 1)
        poisonVignette.strokeColor = .clear
        poisonVignette.alpha = 0
        poisonVignette.zPosition = 90
        hud.addChild(poisonVignette)

        // Barre de PV joueur, en haut au centre.
        let barWidth: CGFloat = 170
        let hpBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: 12), cornerRadius: 6)
        hpBg.position = CGPoint(x: 0, y: h / 2 - 74)
        hpBg.fillColor = SKColor(white: 1, alpha: 0.12)
        hpBg.strokeColor = SKColor(white: 1, alpha: 0.5)
        hpBg.lineWidth = 1
        hud.addChild(hpBg)

        hpBarFill = SKShapeNode(rectOf: CGSize(width: barWidth, height: 12), cornerRadius: 6)
        hpBarFill.fillColor = state.player.color
        hpBarFill.strokeColor = .clear
        hpBg.addChild(hpBarFill)

        aliveLabel = makeLabel("", size: 15, font: UIFont2.bold)
        aliveLabel.horizontalAlignmentMode = .left
        aliveLabel.position = CGPoint(x: -w / 2 + 20, y: h / 2 - 48)
        hud.addChild(aliveLabel)

        zoneLabel = makeLabel("", size: 15, font: UIFont2.bold)
        zoneLabel.horizontalAlignmentMode = .right
        zoneLabel.position = CGPoint(x: w / 2 - 20, y: h / 2 - 48)
        hud.addChild(zoneLabel)

        countdownLabel = makeLabel("", size: 90, font: UIFont2.heavy)
        countdownLabel.position = CGPoint(x: 0, y: 40)
        countdownLabel.zPosition = 95
        hud.addChild(countdownLabel)

        input = InputController(hud: hud, screenSize: size)
        playerController = PlayerController(character: state.player, input: input)
    }

    // MARK: - Countdown (SPEC §5 : spawns placés, contrôles bloqués)

    private func startCountdown() {
        state.phase = .countdown
        input.isEnabled = false

        var steps: [SKAction] = []
        for n in stride(from: GameConfig.countdownSeconds, through: 1, by: -1) {
            steps.append(.run { [weak self] in
                guard let self else { return }
                self.countdownLabel.text = "\(n)"
                self.countdownLabel.setScale(1.6)
                self.countdownLabel.alpha = 1
                self.countdownLabel.run(.group([
                    .scale(to: 1, duration: 0.25),
                    .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.25)]),
                ]))
            })
            steps.append(.wait(forDuration: 1))
        }
        steps.append(.run { [weak self] in
            guard let self else { return }
            self.countdownLabel.text = "GO !"
            self.countdownLabel.alpha = 1
            self.countdownLabel.setScale(1.4)
            self.countdownLabel.run(.sequence([
                .scale(to: 1, duration: 0.15),
                .wait(forDuration: 0.5),
                .fadeOut(withDuration: 0.3),
            ]))
            self.state.phase = .active
            self.input.isEnabled = true
        })
        run(.sequence(steps))
    }

    // MARK: - Boucle principale

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime
        currentGameTime = currentTime

        guard state.phase == .active else { return }

        playerController.update()
        for brain in brains {
            brain.update(dt: dt)
        }
        for character in state.characters {
            character.applyMovement(dt: dt)
        }
        combat.update(dt: dt, characters: state.characters, currentTime: currentTime)
        bushSystem.update(characters: state.characters, currentTime: currentTime)
        zone.update(dt: dt, characters: state.characters)

        refreshHUD()
    }

    override func didSimulatePhysics() {
        updateCamera()
    }

    private func refreshHUD() {
        guard state.player != nil else { return }
        let barWidth: CGFloat = 170
        let fraction = state.player.hpFraction
        hpBarFill.xScale = max(fraction, 0.001)
        hpBarFill.position = CGPoint(x: -barWidth * (1 - fraction) / 2, y: 0)

        aliveLabel.text = "\(state.aliveCount) vivants"
        zoneLabel.text = zone.statusText

        let playerOutside = state.player.isAlive && zone.isOutside(state.player.position)
        poisonVignette.alpha = playerOutside ? 0.22 : 0
    }

    private func updateCamera() {
        guard state.player != nil else { return }
        // Suivi doux du joueur, clampé pour ne pas montrer l'extérieur de l'arène.
        let halfW = size.width / 2 * GameConfig.cameraZoom
        let halfH = size.height / 2 * GameConfig.cameraZoom
        var target = state.player.position
        if halfW * 2 < arenaRect.width {
            target.x = min(max(target.x, halfW), arenaRect.width - halfW)
        } else {
            target.x = arenaRect.midX
        }
        if halfH * 2 < arenaRect.height {
            target.y = min(max(target.y, halfH), arenaRect.height - halfH)
        } else {
            target.y = arenaRect.midY
        }

        let current = cameraNode.position
        var next = CGPoint(
            x: current.x + (target.x - current.x) * 0.12,
            y: current.y + (target.y - current.y) * 0.12
        )
        if shakeAmount > 0.1 {
            next.x += .random(in: -shakeAmount...shakeAmount)
            next.y += .random(in: -shakeAmount...shakeAmount)
            shakeAmount *= 0.85
        }
        cameraNode.position = next
    }

    /// Screen shake léger sur impacts / morts proches (SPEC §8).
    func addShake(_ amount: CGFloat) {
        // Atténué avec la distance au joueur géré par les appelants si besoin.
        shakeAmount = min(shakeAmount + amount, 14)
    }

    // MARK: - Mort et fin de match

    private func handleDeath(of character: Character) {
        FX.deathPoof(at: character.position, color: character.color, in: worldLayer)
        let distToPlayer = character.position.distance(to: state.player.position)
        if distToPlayer < 500 {
            addShake(character.isPlayer ? 10 : 6)
        }

        guard state.phase == .active else { return }
        if character.isPlayer {
            endMatch(victory: false)
        } else if state.aliveCount <= 1 && state.player.isAlive {
            endMatch(victory: true)
        }
    }

    private func endMatch(victory: Bool) {
        state.phase = .ended
        input.isEnabled = false
        let rank = state.playerRank
        let total = state.totalCount

        run(.sequence([
            .wait(forDuration: 1.4),
            .run { [weak self] in
                guard let self, let view = self.view else { return }
                let result = ResultScene(size: self.size, victory: victory, rank: rank, total: total)
                view.presentScene(result, transition: .fade(withDuration: 0.5))
            },
        ]))
    }

    // MARK: - Physique

    func didBegin(_ contact: SKPhysicsContact) {
        guard state.phase == .active else { return }
        combat.handleContact(contact)
    }

    // MARK: - BotWorld

    var allCharacters: [Character] { state.characters }

    func lineOfSightClear(from: CGPoint, to: CGPoint) -> Bool {
        guard from.distance(to: to) > 1 else { return true }
        var clear = true
        physicsWorld.enumerateBodies(alongRayStart: from, end: to) { body, _, _, stop in
            if body.categoryBitMask & PhysicsCategory.wall != 0 {
                clear = false
                stop.pointee = true
            }
        }
        return clear
    }

    // MARK: - Touches → InputController

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesBegan(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesMoved(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesEnded(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesEnded(touches)
    }
}
