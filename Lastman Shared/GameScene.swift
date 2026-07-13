//
//  GameScene.swift
//  Lastman
//
//  Le match : arène fixe, caméra qui suit le joueur, HUD, countdown → active
//  → ended (SPEC §5). Orchestration des systèmes, l'état vit dans GameState.
//

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate, BotWorld {

    private enum ArenaStyle {
        static let floor = SKColor(red: 0.075, green: 0.085, blue: 0.095, alpha: 1)
        static let floorInset = SKColor(red: 0.105, green: 0.115, blue: 0.125, alpha: 1)
        static let floorDot = SKColor(white: 1, alpha: 0.055)
        static let border = SKColor(red: 0.78, green: 0.88, blue: 0.95, alpha: 0.72)
        static let borderGlow = SKColor(red: 0.34, green: 0.62, blue: 0.78, alpha: 0.16)
        static let obstacle = SKColor(red: 0.17, green: 0.20, blue: 0.22, alpha: 1)
        static let obstacleTop = SKColor(red: 0.24, green: 0.28, blue: 0.30, alpha: 0.75)
        static let obstacleStroke = SKColor(red: 0.86, green: 0.93, blue: 0.96, alpha: 0.50)
        static let obstacleShadow = SKColor(white: 0, alpha: 0.22)
    }

    private let difficulty: Difficulty
    private let botCount: Int
    private let weaponStyle: WeaponStyle
    private let quickStart: Bool
    private let playerSpawnOptions: [CGPoint]

    private let state = GameState()
    private let worldLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let hud = SKNode()
    private let obstacleLayout: [(center: CGPoint, radius: CGFloat)] = [
        (CGPoint(x: 300, y: 420), 48),
        (CGPoint(x: 900, y: 420), 48),
        (CGPoint(x: 600, y: 800), 58),
        (CGPoint(x: 180, y: 850), 52),
        (CGPoint(x: 1020, y: 850), 52),
        (CGPoint(x: 420, y: 1180), 48),
        (CGPoint(x: 800, y: 1250), 52),
    ]

    private var input: InputController!
    private var playerController: PlayerController!
    private var combat: CombatSystem!
    private var zoneImpl: ZoneSystem!
    private var bushImpl: BushSystem!
    private var breakableImpl: BreakableSystem!
    var zone: ZoneSystem { zoneImpl }
    var bushSystem: BushSystem { bushImpl }
    private var brains: [BotBrain] = []

    private var lastUpdateTime: TimeInterval = 0
    private var currentGameTime: TimeInterval = 0
    private var shakeAmount: CGFloat = 0
    private var topThreeAnnounced = false
    private var hitStopGeneration = 0

    // HUD
    private var hpBarBackground: SKShapeNode!
    private var hpBarFill: SKShapeNode!
    private var aliveLabel: SKLabelNode!
    private var zoneLabel: SKLabelNode!
    private var weaponLabel: SKLabelNode!
    private var statusLabel: SKLabelNode!
    private var feedLabel: SKLabelNode!
    private var topLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var impactFlash: SKShapeNode!
    private var spawnChoiceOverlay: SKNode?
    private var spawnMarkers: [SKNode] = []
    private var countdownLabel: SKLabelNode!
    private var poisonVignette: SKShapeNode!

    // MARK: - Init

    init(size: CGSize, difficulty: Difficulty, botCount: Int, weaponStyle: WeaponStyle = .normal,
         quickStart: Bool = false) {
        self.difficulty = difficulty
        self.botCount = max(1, botCount)
        self.weaponStyle = weaponStyle
        self.quickStart = quickStart
        self.playerSpawnOptions = GameScene.makePlayerSpawnOptions()
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

        combat = CombatSystem(worldLayer: worldLayer, playerWeaponStyle: weaponStyle)
        combat.onImpactShake = { [weak self] amount in
            self?.addShake(amount)
        }
        combat.onPlayerHit = { [weak self] target in
            self?.addFeed(text: "Tu touches \(target.displayName)")
        }
        combat.onDamageDealt = { [weak self] owner, target, amount in
            guard let self else { return }
            if owner.isPlayer {
                self.state.recordPlayerDamageDealt(amount)
            }
        }
        combat.onHitStop = { [weak self] duration in
            self?.performHitStop(duration: duration)
        }

        if quickStart {
            selectPlayerSpawn(playerSpawnOptions[0])
        } else {
            presentSpawnChoice()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil else { return }
        layoutHUD()
        input?.updateScreenSize(size)
    }

    private static func makePlayerSpawnOptions() -> [CGPoint] {
        let options = [
            CGPoint(x: 600, y: 180),
            CGPoint(x: 185, y: 315),
            CGPoint(x: 1015, y: 330),
            CGPoint(x: 250, y: 1180),
            CGPoint(x: 930, y: 1220),
            CGPoint(x: 600, y: 1410),
        ].shuffled()
        return Array(options.prefix(3))
    }

    private var arenaRect: CGRect {
        CGRect(origin: .zero, size: GameConfig.arenaSize)
    }

    private func buildArena() {
        // Sol arrondi + repères ponctuels réguliers : lisible sans l'effet "papier quadrillé".
        let floor = SKShapeNode(rect: arenaRect, cornerRadius: 38)
        floor.fillColor = ArenaStyle.floor
        floor.strokeColor = .clear
        floor.zPosition = 0
        worldLayer.addChild(floor)

        let inset = SKShapeNode(rect: arenaRect.insetBy(dx: 26, dy: 26), cornerRadius: 32)
        inset.fillColor = ArenaStyle.floorInset
        inset.strokeColor = .clear
        inset.alpha = 0.32
        inset.zPosition = 0.2
        worldLayer.addChild(inset)

        addFloorDots()

        // Murs extérieurs : bord physique rectangulaire, rendu arrondi et plus doux.
        let borderGlow = SKShapeNode(rect: arenaRect.insetBy(dx: -2, dy: -2), cornerRadius: 40)
        borderGlow.fillColor = .clear
        borderGlow.strokeColor = ArenaStyle.borderGlow
        borderGlow.lineWidth = 14
        borderGlow.zPosition = 21
        worldLayer.addChild(borderGlow)

        let borderNode = SKShapeNode(rect: arenaRect, cornerRadius: 38)
        borderNode.fillColor = .clear
        borderNode.strokeColor = ArenaStyle.border
        borderNode.lineWidth = 4
        borderNode.glowWidth = 1.5
        borderNode.zPosition = 22
        worldLayer.addChild(borderNode)

        let edge = SKNode()
        let edgeBody = SKPhysicsBody(edgeLoopFrom: arenaRect)
        edgeBody.categoryBitMask = PhysicsCategory.wall
        edgeBody.friction = 0
        edge.physicsBody = edgeBody
        worldLayer.addChild(edge)

        // Obstacles intérieurs, layout fixe (SPEC §2 : pas de procédural).
        for spec in obstacleLayout {
            worldLayer.addChild(makeObstacle(center: spec.center, radius: spec.radius))
        }
    }

    private func addFloorDots() {
        let dots = CGMutablePath()
        let step: CGFloat = 112
        let radius: CGFloat = 2.6
        var y: CGFloat = step
        while y < arenaRect.height - step * 0.5 {
            var x: CGFloat = step
            while x < arenaRect.width - step * 0.5 {
                let dotRect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                dots.addEllipse(in: dotRect)
                x += step
            }
            y += step
        }

        let dotNode = SKShapeNode(path: dots)
        dotNode.fillColor = ArenaStyle.floorDot
        dotNode.strokeColor = .clear
        dotNode.zPosition = 1
        worldLayer.addChild(dotNode)
    }

    private func makeObstacle(center: CGPoint, radius: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = center
        container.zPosition = 2

        let shadow = SKShapeNode(circleOfRadius: radius)
        shadow.position = CGPoint(x: 0, y: -5)
        shadow.fillColor = ArenaStyle.obstacleShadow
        shadow.strokeColor = .clear
        container.addChild(shadow)

        let base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = ArenaStyle.obstacle
        base.strokeColor = ArenaStyle.obstacleStroke
        base.lineWidth = 2
        base.glowWidth = 0.5
        container.addChild(base)

        let shine = SKShapeNode(circleOfRadius: radius * 0.56)
        shine.position = CGPoint(x: 0, y: radius * 0.18)
        shine.fillColor = ArenaStyle.obstacleTop
        shine.strokeColor = .clear
        shine.alpha = 0.55
        container.addChild(shine)

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        body.friction = 0
        container.physicsBody = body
        return container
    }

    private func buildBushes() {
        let layout: [(center: CGPoint, radii: CGSize)] = [
            (CGPoint(x: 170, y: 260), CGSize(width: 72, height: 72)),
            (CGPoint(x: 1030, y: 300), CGSize(width: 72, height: 72)),
            (CGPoint(x: 600, y: 560), CGSize(width: 82, height: 82)),
            (CGPoint(x: 420, y: 1010), CGSize(width: 70, height: 70)),
            (CGPoint(x: 880, y: 1080), CGSize(width: 70, height: 70)),
            (CGPoint(x: 150, y: 1300), CGSize(width: 72, height: 72)),
            (CGPoint(x: 1050, y: 1360), CGSize(width: 72, height: 72)),
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

    private func buildBreakables() {
        breakableImpl = BreakableSystem(worldLayer: worldLayer,
                                        arenaRect: arenaRect,
                                        blockedAreas: obstacleLayout)
        breakableImpl.onPlayerPickupCollected = { [weak self] in
            self?.state.recordPlayerPickup()
        }
        breakableImpl.onPlayerBreakableDestroyed = { [weak self] in
            self?.state.recordPlayerBreakableDestroyed()
        }
        breakableImpl.onDamageDealt = { [weak self] owner, target, amount in
            guard let self, owner.isPlayer, target !== owner else { return }
            self.state.recordPlayerDamageDealt(amount)
        }
        breakableImpl.spawnInitial(characters: state.characters)
    }

    private func spawnCharacters() {
        let playerColor = SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1)
        let player = Character(name: "Toi", isPlayer: true, color: playerColor,
                               position: playerSpawnOptions[0])
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
            let personality = BotPersonality.allCases[i % BotPersonality.allCases.count]
            let hue = (CGFloat(i) * 0.11 + 0.98).truncatingRemainder(dividingBy: 1)
            let color = SKColor(hue: hue, saturation: 0.6, brightness: 0.95, alpha: 1)
            let bot = Character(name: "Bot \(i + 1) \(personality.label)", isPlayer: false, color: color,
                                position: botSpawns[i])
            state.addBot(bot)
            worldLayer.addChild(bot.node)
            brains.append(BotBrain(bot: bot, world: self, difficulty: difficulty, personality: personality))
        }

        for character in state.characters {
            character.onDeath = { [weak self] dead in
                self?.handleDeath(of: dead)
            }
        }
    }

    private func buildCameraAndHUD() {
        cameraNode.position = state.player.position
        cameraNode.setScale(cameraZoom)
        addChild(cameraNode)
        camera = cameraNode

        // Les enfants de la caméra sont rendus en points écran (le transform
        // de la caméra s'annule) : positions HUD = coordonnées écran.
        hud.zPosition = 100
        cameraNode.addChild(hud)

        // Vignette rouge quand le joueur prend du poison hors zone.
        poisonVignette = SKShapeNode()
        poisonVignette.fillColor = SKColor(red: 0.8, green: 0.1, blue: 0.15, alpha: 1)
        poisonVignette.strokeColor = .clear
        poisonVignette.alpha = 0
        poisonVignette.zPosition = 90
        hud.addChild(poisonVignette)

        impactFlash = SKShapeNode()
        impactFlash.fillColor = .white
        impactFlash.strokeColor = .clear
        impactFlash.alpha = 0
        impactFlash.zPosition = 91
        hud.addChild(impactFlash)

        // Barre de PV joueur, en haut au centre.
        let barWidth: CGFloat = 170
        let hpBg = SKShapeNode(rectOf: CGSize(width: barWidth, height: 12), cornerRadius: 6)
        hpBg.fillColor = SKColor(white: 1, alpha: 0.12)
        hpBg.strokeColor = SKColor(white: 1, alpha: 0.5)
        hpBg.lineWidth = 1
        hud.addChild(hpBg)
        hpBarBackground = hpBg

        hpBarFill = SKShapeNode(rectOf: CGSize(width: barWidth, height: 12), cornerRadius: 6)
        hpBarFill.fillColor = state.player.color
        hpBarFill.strokeColor = .clear
        hpBg.addChild(hpBarFill)

        aliveLabel = makeLabel("", size: 15, font: UIFont2.bold)
        aliveLabel.horizontalAlignmentMode = .left
        hud.addChild(aliveLabel)

        weaponLabel = makeLabel(weaponStyle.label.uppercased(), size: 13,
                                color: SKColor(white: 1, alpha: 0.48), font: UIFont2.bold)
        hud.addChild(weaponLabel)

        statusLabel = makeLabel("", size: 12, color: SKColor(white: 1, alpha: 0.62), font: UIFont2.bold)
        hud.addChild(statusLabel)

        zoneLabel = makeLabel("", size: 15, font: UIFont2.bold)
        zoneLabel.horizontalAlignmentMode = .right
        hud.addChild(zoneLabel)

        feedLabel = makeLabel("", size: 13, color: SKColor(white: 1, alpha: 0.62), font: UIFont2.bold)
        feedLabel.horizontalAlignmentMode = .left
        hud.addChild(feedLabel)

        topLabel = makeLabel("", size: 30, color: SKColor(red: 0.95, green: 0.86, blue: 0.42, alpha: 1), font: UIFont2.heavy)
        topLabel.position = CGPoint(x: 0, y: 94)
        topLabel.zPosition = 96
        topLabel.alpha = 0
        hud.addChild(topLabel)

        comboLabel = makeLabel("", size: 38, color: state.player.color, font: UIFont2.heavy)
        comboLabel.position = CGPoint(x: 0, y: 138)
        comboLabel.zPosition = 97
        comboLabel.alpha = 0
        hud.addChild(comboLabel)

        countdownLabel = makeLabel("", size: 90, font: UIFont2.heavy)
        countdownLabel.position = CGPoint(x: 0, y: 40)
        countdownLabel.zPosition = 95
        hud.addChild(countdownLabel)

        input = InputController(hud: hud, screenSize: size)
        playerController = PlayerController(character: state.player, input: input)
        layoutHUD()
    }

    private func layoutHUD() {
        let w = size.width
        let h = size.height
        let topInset: CGFloat = h < 520 ? 30 : 48
        let hpInset: CGFloat = h < 520 ? 50 : 74
        let feedInset: CGFloat = h < 520 ? 58 : 82

        poisonVignette?.path = CGPath(rect: CGRect(x: -w * 0.6,
                                                   y: -h * 0.6,
                                                   width: w * 1.2,
                                                   height: h * 1.2),
                                      transform: nil)
        impactFlash?.path = CGPath(rect: CGRect(x: -w * 0.6,
                                                y: -h * 0.6,
                                                width: w * 1.2,
                                                height: h * 1.2),
                                   transform: nil)
        hpBarBackground?.position = CGPoint(x: 0, y: h / 2 - hpInset)
        aliveLabel?.position = CGPoint(x: -w / 2 + 20, y: h / 2 - topInset)
        weaponLabel?.position = CGPoint(x: 0, y: h / 2 - topInset)
        statusLabel?.position = CGPoint(x: 0, y: h / 2 - topInset - 22)
        zoneLabel?.position = CGPoint(x: w / 2 - 20, y: h / 2 - topInset)
        feedLabel?.position = CGPoint(x: -w / 2 + 20, y: h / 2 - feedInset)
    }

    private func presentSpawnChoice() {
        state.phase = .preparing
        input.isEnabled = false
        cameraNode.position = CGPoint(x: arenaRect.midX, y: arenaRect.midY)

        let overlay = SKNode()
        overlay.zPosition = 98
        hud.addChild(overlay)
        spawnChoiceOverlay = overlay

        let title = makeLabel("CHOISIS TON SPAWN", size: 24, font: UIFont2.heavy)
        title.position = CGPoint(x: 0, y: 118)
        overlay.addChild(title)

        let subtitle = makeLabel("le match démarre après ton choix", size: 13, color: SKColor(white: 1, alpha: 0.52))
        subtitle.position = CGPoint(x: 0, y: 86)
        overlay.addChild(subtitle)

        let spacing: CGFloat = 112
        for (index, point) in playerSpawnOptions.enumerated() {
            addSpawnMarker(index: index, at: point)
            let button = MenuButton(text: "\(index + 1)", width: 72, height: 58, fontSize: 22) { [weak self] in
                self?.selectPlayerSpawn(point)
            }
            button.position = CGPoint(x: CGFloat(index - 1) * spacing, y: 30)
            overlay.addChild(button)
        }
    }

    private func addSpawnMarker(index: Int, at point: CGPoint) {
        let marker = SKNode()
        marker.position = point
        marker.zPosition = 32

        let ring = SKShapeNode(circleOfRadius: 30)
        ring.strokeColor = state.player.color
        ring.fillColor = state.player.color.withAlphaComponent(0.12)
        ring.lineWidth = 3
        marker.addChild(ring)

        let label = makeLabel("\(index + 1)", size: 24, color: .white, font: UIFont2.heavy)
        marker.addChild(label)

        worldLayer.addChild(marker)
        spawnMarkers.append(marker)
        marker.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.5),
            .scale(to: 1.0, duration: 0.5),
        ])))
    }

    private func selectPlayerSpawn(_ point: CGPoint) {
        state.player.node.position = point
        cameraNode.position = point
        for marker in spawnMarkers {
            marker.removeFromParent()
        }
        spawnMarkers.removeAll()
        buildBreakables()
        spawnChoiceOverlay?.removeFromParent()
        spawnChoiceOverlay = nil
        Haptics.selectionChanged()
        startCountdown()
    }

    // MARK: - Countdown (SPEC §5 : spawns placés, contrôles bloqués)

    private func startCountdown() {
        state.phase = .countdown
        input.isEnabled = false

        var steps: [SKAction] = []
        let countdownSeconds = quickStart
            ? GameConfig.quickRestartCountdownSeconds
            : GameConfig.countdownSeconds
        for n in stride(from: countdownSeconds, through: 1, by: -1) {
            steps.append(.run { [weak self] in
                guard let self else { return }
                self.countdownLabel.text = "\(n)"
                Haptics.countdownTick()
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
            self.state.startMatch(at: self.currentGameTime)
            self.input.isEnabled = true
            Haptics.matchStarted()
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

        let playerHPBefore = state.player.hp
        playerController.update()
        updatePlayerAutoShoot()
        for brain in brains {
            brain.update(dt: dt)
        }
        for character in state.characters {
            character.applyMovement(dt: dt)
        }
        combat.update(dt: dt, characters: state.characters, currentTime: currentTime)
        breakableImpl.update(currentTime: currentTime, characters: state.characters)
        bushSystem.update(characters: state.characters, currentTime: currentTime)
        zone.update(dt: dt, characters: state.characters)
        let damageTaken = max(0, playerHPBefore - state.player.hp)
        state.recordPlayerDamageTaken(damageTaken)
        if damageTaken > 0 {
            state.breakPlayerKillStreak()
            comboLabel.removeAllActions()
            comboLabel.run(.fadeOut(withDuration: 0.12))
        }

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
        statusLabel.text = playerStatusText()
        statusLabel.alpha = statusLabel.text?.isEmpty == false ? 1 : 0
        if state.aliveCount <= 3, !topThreeAnnounced {
            announceTopThree()
        }

        let playerOutside = state.player.isAlive && zone.isOutside(state.player.position)
        poisonVignette.alpha = playerOutside ? 0.22 : 0
    }

    private func updateCamera() {
        guard state.player != nil else { return }
        // Suivi doux du joueur, clampé pour ne pas montrer l'extérieur de l'arène.
        let zoom = cameraZoom
        cameraNode.setScale(zoom)
        let halfW = size.width / 2 * zoom
        let halfH = size.height / 2 * zoom
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

    private func updatePlayerAutoShoot() {
        guard state.player.isAlive, state.player.aimIntent == nil else { return }
        guard let target = nearestAutoShootTarget() else { return }
        state.player.aimIntent = CGVector(from: state.player.position, to: target.position).normalized
    }

    private func nearestAutoShootTarget() -> Character? {
        let maxDistance = weaponStyle.projectileRange
        let playerPosition = state.player.position
        let candidates = state.characters.filter { character in
            character !== state.player
                && character.isAlive
                && playerPosition.distance(to: character.position) <= maxDistance
                && bushSystem.canPerceive(character)
                && lineOfSightClear(from: playerPosition, to: character.position)
        }
        return candidates.min {
            playerPosition.distance(to: $0.position) < playerPosition.distance(to: $1.position)
        }
    }

    private var cameraZoom: CGFloat {
        size.width > size.height ? GameConfig.landscapeCameraZoom : GameConfig.cameraZoom
    }

    /// Screen shake léger sur impacts / morts proches (SPEC §8).
    func addShake(_ amount: CGFloat) {
        // Atténué avec la distance au joueur géré par les appelants si besoin.
        shakeAmount = min(shakeAmount + amount, 14)
    }

    private func performHitStop(duration: TimeInterval) {
        guard state.phase == .active, let view else { return }
        hitStopGeneration += 1
        let generation = hitStopGeneration
        impactFlash.removeAllActions()
        impactFlash.alpha = 0.09
        impactFlash.run(.fadeOut(withDuration: 0.08))
        view.isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak view] in
            guard let self, self.hitStopGeneration == generation else { return }
            view?.isPaused = false
            self.lastUpdateTime = 0
        }
    }

    // MARK: - Mort et fin de match

    private func handleDeath(of character: Character) {
        FX.deathPoof(at: character.position, color: character.color, in: worldLayer)
        addFeed(text: feedText(for: character))
        if character.lastDamageSource?.isPlayer == true, !character.isPlayer {
            let streak = state.recordPlayerKill(at: currentGameTime)
            FX.playerKillBurst(at: character.position, color: state.player.color,
                               streak: streak, in: worldLayer)
            showKillStreak(streak)
            Haptics.playerKill(streak: streak)
            performHitStop(duration: GameConfig.killHitStopDuration)
        }
        let distToPlayer = character.position.distance(to: state.player.position)
        if distToPlayer < 500 {
            addShake(character.isPlayer ? 10 : 6)
        }

        guard state.phase == .active else { return }
        if character.isPlayer {
            state.recordPlayerDeath(cause: playerDeathCause())
            endMatch(victory: false)
        } else if state.aliveCount <= 1 && state.player.isAlive {
            endMatch(victory: true)
        }
    }

    private func feedText(for dead: Character) -> String {
        guard let killer = dead.lastDamageSource, killer !== dead else {
            return "\(dead.displayName) éliminé"
        }
        return "\(killer.displayName) → \(dead.displayName)"
    }

    private func addFeed(text: String) {
        feedLabel.text = text
        feedLabel.alpha = 1
        feedLabel.removeAction(forKey: "feed")
        feedLabel.run(.sequence([
            .wait(forDuration: 2.2),
            .fadeOut(withDuration: 0.35),
        ]), withKey: "feed")
    }

    private func showKillStreak(_ streak: Int) {
        comboLabel.text = streak > 1 ? "x\(streak) SÉRIE" : "ÉLIMINATION"
        comboLabel.setScale(0.55)
        comboLabel.alpha = 1
        comboLabel.removeAllActions()
        comboLabel.run(.sequence([
            .scale(to: 1.15, duration: 0.1),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.75),
            .group([
                .moveBy(x: 0, y: 14, duration: 0.22),
                .fadeOut(withDuration: 0.22),
            ]),
            .moveBy(x: 0, y: -14, duration: 0),
        ]))
    }

    private func playerStatusText() -> String {
        var items: [String] = []
        if state.player.isShieldActive {
            items.append("SHIELD \(Int(ceil(state.player.shieldTimeRemaining)))s")
        }
        if state.player.isSpeedBoostActive {
            items.append("SPEED \(Int(ceil(state.player.speedBoostTimeRemaining)))s")
        }
        return items.joined(separator: " · ")
    }

    private func playerDeathCause() -> String {
        if zone.isOutside(state.player.position) {
            return "Mort dans la zone."
        }
        if let killer = state.player.lastDamageSource {
            return "\(killer.displayName) t'a éliminé."
        }
        return "Éliminé."
    }

    private func announceTopThree() {
        topThreeAnnounced = true
        zone.intensifyFinale()
        topLabel.text = "TOP 3"
        topLabel.setScale(0.65)
        topLabel.alpha = 0
        topLabel.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.12),
                .scale(to: 1.1, duration: 0.18),
            ]),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 1.0),
            .fadeOut(withDuration: 0.35),
        ]))
        Haptics.matchStarted()
        addShake(6)
    }

    private func endMatch(victory: Bool) {
        state.phase = .ended
        input.isEnabled = false
        if victory {
            Haptics.victory()
        } else {
            Haptics.defeat()
        }
        let summary = state.finishMatch(victory: victory, at: currentGameTime)

        run(.sequence([
            .wait(forDuration: victory ? 0.9 : 0.65),
            .run { [weak self] in
                guard let self, let view = self.view else { return }
                let result = ResultScene(size: self.size, summary: summary)
                view.presentScene(result, transition: .fade(withDuration: 0.5))
            },
        ]))
    }

    // MARK: - Physique

    func didBegin(_ contact: SKPhysicsContact) {
        guard state.phase == .active else { return }
        if breakableImpl.handleContact(contact, characters: state.characters) { return }
        combat.handleContact(contact)
    }

    // MARK: - BotWorld

    var allCharacters: [Character] { state.characters }

    func healingObjective(for character: Character) -> HealingObjective? {
        guard let objective = breakableImpl.nearestHealingObjective(to: character.position,
                                                                    maxDistance: GameConfig.botHealObjectiveRadius),
              !zone.isOutside(objective.position) else { return nil }
        return objective
    }

    func lineOfSightClear(from: CGPoint, to: CGPoint) -> Bool {
        guard from.distance(to: to) > 1 else { return true }
        var clear = true
        physicsWorld.enumerateBodies(alongRayStart: from, end: to) { body, _, _, stop in
            if body.categoryBitMask & (PhysicsCategory.wall | PhysicsCategory.breakable) != 0 {
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
