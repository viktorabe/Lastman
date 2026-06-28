//
//  GameScene.swift
//  Lastman
//
//  Orchestration du match (SPEC §5, §9) : arène, caméra, joueur + bots,
//  systèmes (combat / buissons / zone), états Countdown → Active → Ended,
//  et classement. GameState léger : les systèmes portent la vérité, les
//  SKNode ne font que refléter.
//

import SpriteKit

final class GameScene: SKScene, SKPhysicsContactDelegate, BotWorld {

    private enum MatchState { case countdown, active, ended }

    // Configuration de la partie
    private let difficulty: Difficulty
    private let botCount: Int

    // Acteurs
    private var playerEntity: Player!
    var player: Player { playerEntity }       // satisfait BotWorld
    private var bots: [Bot] = []
    private var allCharacters: [Character] {
        var all: [Character] = [player]
        all.append(contentsOf: bots)
        return all
    }
    private var nodeToCharacter: [ObjectIdentifier: Character] = [:]

    // Systèmes
    private let cam = SKCameraNode()
    private let input = InputController()
    private var combat: CombatSystem!
    private let bush = BushSystem()
    private var zone: ZoneSystem!

    // État
    private var matchState: MatchState = .countdown
    private var zoneStarted = false
    private var playerRank: Int?
    private var lastUpdateTime: TimeInterval = 0
    private var totalPlayers: Int { bots.count + 1 }

    // Juice
    private var shakeMag: CGFloat = 0
    private var zoneVignette: SKSpriteNode!

    // MARK: Init

    init(size: CGSize, difficulty: Difficulty, botCount: Int) {
        self.difficulty = difficulty
        self.botCount = botCount
        super.init(size: size)
        scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        size = view.bounds.size
        anchorPoint = .zero
        backgroundColor = SKColor(white: 0.05, alpha: 1.0)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        combat = CombatSystem(scene: self)

        buildArena()
        setUpCamera()
        zone = ZoneSystem(scene: self, center: CGPoint(x: GameConfig.arenaSize.width / 2,
                                                       y: GameConfig.arenaSize.height / 2))
        bush.build(in: self, layout: bushLayout())
        spawnCharacters()
        startCountdown()
    }

    // MARK: Construction de l'arène

    private func buildArena() {
        let arena = CGRect(origin: .zero, size: GameConfig.arenaSize)

        let floor = SKShapeNode(rect: arena)
        floor.fillColor = SKColor(white: 0.09, alpha: 1.0)
        floor.strokeColor = .clear
        floor.zPosition = -10
        addChild(floor)

        let path = CGMutablePath()
        let step: CGFloat = 120
        var x: CGFloat = 0
        while x <= arena.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: arena.height)); x += step }
        var y: CGFloat = 0
        while y <= arena.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: arena.width, y: y)); y += step }
        let grid = SKShapeNode(path: path)
        grid.strokeColor = SKColor(white: 1, alpha: 0.04)
        grid.lineWidth = 1
        grid.zPosition = -9
        addChild(grid)

        let border = SKShapeNode(rect: arena)
        border.fillColor = .clear
        border.strokeColor = SKColor(white: 1, alpha: 0.5)
        border.lineWidth = GameConfig.wallThickness * 0.5
        border.zPosition = -8
        addChild(border)

        let edge = SKPhysicsBody(edgeLoopFrom: arena)
        edge.categoryBitMask = PhysicsCategory.wall
        physicsBody = edge

        for rect in obstacleLayout() { addObstacle(rect) }
    }

    private func obstacleLayout() -> [CGRect] {
        let a = GameConfig.arenaSize
        return [
            CGRect(x: a.width * 0.30, y: a.height * 0.30, width: 220, height: 60),
            CGRect(x: a.width * 0.55, y: a.height * 0.58, width: 60, height: 260),
            CGRect(x: a.width * 0.18, y: a.height * 0.70, width: 180, height: 60),
            CGRect(x: a.width * 0.62, y: a.height * 0.20, width: 60, height: 200),
        ]
    }

    private func bushLayout() -> [(CGPoint, CGFloat)] {
        let a = GameConfig.arenaSize
        return [
            (CGPoint(x: a.width * 0.25, y: a.height * 0.45), 90),
            (CGPoint(x: a.width * 0.72, y: a.height * 0.40), 80),
            (CGPoint(x: a.width * 0.45, y: a.height * 0.72), 100),
            (CGPoint(x: a.width * 0.50, y: a.height * 0.25), 75),
        ]
    }

    private func addObstacle(_ rect: CGRect) {
        let node = SKShapeNode(rect: CGRect(origin: .zero, size: rect.size), cornerRadius: 8)
        node.position = rect.origin
        node.fillColor = SKColor(white: 0.22, alpha: 1.0)
        node.strokeColor = SKColor(white: 1, alpha: 0.25)
        node.lineWidth = 2
        node.zPosition = -5

        let body = SKPhysicsBody(rectangleOf: rect.size, center: CGPoint(x: rect.width / 2, y: rect.height / 2))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        node.physicsBody = body
        addChild(node)
    }

    private func setUpCamera() {
        addChild(cam)
        camera = cam

        zoneVignette = SKSpriteNode(color: SKColor(red: 0.8, green: 0.1, blue: 0.15, alpha: 1),
                                    size: CGSize(width: 4000, height: 4000))
        zoneVignette.alpha = 0
        zoneVignette.zPosition = 900
        cam.addChild(zoneVignette)

        input.attach(to: cam)
    }

    // MARK: Spawns

    private func spawnCharacters() {
        let a = GameConfig.arenaSize
        let center = CGPoint(x: a.width / 2, y: a.height / 2)

        playerEntity = Player(position: CGPoint(x: center.x, y: a.height * 0.18))
        addChild(player.node)
        nodeToCharacter[ObjectIdentifier(player.node)] = player
        cam.position = player.position

        let ring = min(a.width, a.height) * 0.34
        for i in 0..<botCount {
            let angle = CGFloat(i) / CGFloat(botCount) * 2 * .pi + .pi / 2
            let pos = center + CGVector(angle: angle) * ring
            let bot = Bot(color: botColor(i), position: pos, difficulty: difficulty, world: self)
            bots.append(bot)
            addChild(bot.node)
            nodeToCharacter[ObjectIdentifier(bot.node)] = bot
        }
    }

    private func botColor(_ index: Int) -> SKColor {
        // Teintes distinctes pour différencier les bots (SPEC §8).
        let hue = CGFloat(index) / CGFloat(max(botCount, 1))
        return SKColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1)
    }

    // MARK: Compte à rebours

    private func startCountdown() {
        matchState = .countdown
        input.setEnabled(false)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.fontSize = 96
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 1100
        cam.addChild(label)

        var actions: [SKAction] = []
        for n in stride(from: GameConfig.countdownSeconds, through: 1, by: -1) {
            actions.append(.run {
                label.text = "\(n)"
                label.setScale(1.5)
                label.run(.scale(to: 1, duration: 0.3))
            })
            actions.append(.wait(forDuration: 1))
        }
        actions.append(.run { label.text = "GO!" })
        actions.append(.wait(forDuration: 0.5))
        actions.append(.run { [weak self] in
            label.removeFromParent()
            self?.matchState = .active
            self?.input.setEnabled(true)
        })
        run(.sequence(actions))
    }

    // MARK: Boucle de jeu

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime
        guard matchState == .active else { return }

        if !zoneStarted { zone.start(now: currentTime); zoneStarted = true }

        let living = allCharacters.filter { $0.isAlive }
        bush.update(characters: living, now: currentTime)

        player.apply(move: input.moveVector, aim: input.aimVector)
        if input.isFiring {
            combat.tryFire(from: player, direction: player.aimDirection, now: currentTime)
        }

        for bot in bots where bot.isAlive {
            bot.brain.update(now: currentTime, dt: dt)
        }

        zone.update(now: currentTime, dt: dt, characters: living)
        updateZoneVignette()
        processDeaths()
        checkEnd()
    }

    override func didFinishUpdate() {
        // Caméra qui suit le joueur, bornée à l'arène, + screen shake.
        let half = CGSize(width: size.width / 2, height: size.height / 2)
        let a = GameConfig.arenaSize
        let p = player.position
        var x = a.width > size.width ? min(max(p.x, half.width), a.width - half.width) : a.width / 2
        var y = a.height > size.height ? min(max(p.y, half.height), a.height - half.height) : a.height / 2
        if shakeMag > 0.5 {
            x += CGFloat.random(in: -shakeMag...shakeMag)
            y += CGFloat.random(in: -shakeMag...shakeMag)
            shakeMag *= 0.85
        }
        cam.position = CGPoint(x: x, y: y)
    }

    private func updateZoneVignette() {
        let outside = !zone.isInside(player.position)
        let target: CGFloat = outside ? 0.22 : 0
        zoneVignette.alpha += (target - zoneVignette.alpha) * 0.2
    }

    // MARK: Morts et fin de match

    private func processDeaths() {
        for c in allCharacters where c.isAlive && c.hp <= 0 {
            let aliveNow = allCharacters.filter { $0.isAlive }.count
            if c === player { playerRank = aliveNow }
            FX.deathPoof(at: c.position, color: c.color, in: self)
            triggerShake(9)
            c.kill()
        }
    }

    private func checkEnd() {
        guard matchState == .active else { return }
        if !player.isAlive {
            endMatch(victory: false, rank: playerRank ?? totalPlayers)
        } else if bots.allSatisfy({ !$0.isAlive }) {
            endMatch(victory: true, rank: 1)
        }
    }

    private func endMatch(victory: Bool, rank: Int) {
        guard matchState == .active else { return }
        matchState = .ended
        input.setEnabled(false)
        let total = totalPlayers
        run(.sequence([.wait(forDuration: 1.3), .run { [weak self] in
            guard let self, let view = self.view else { return }
            let result = ResultScene.make(victory: victory, rank: rank, total: total, size: view.bounds.size)
            view.presentScene(result, transition: .crossFade(withDuration: 0.6))
        }]))
    }

    private func triggerShake(_ mag: CGFloat) { shakeMag = max(shakeMag, mag) }

    // MARK: BotWorld

    var zoneCenter: CGPoint { zone.center }
    var zoneRadius: CGFloat { zone.currentRadius }
    var zoneIsShrinking: Bool { zone.isShrinking }

    func isInsideZone(_ p: CGPoint) -> Bool { zone.isInside(p) }

    func hasLineOfSight(from a: CGPoint, to b: CGPoint) -> Bool {
        var blocked = false
        physicsWorld.enumerateBodies(alongRayStart: a, end: b) { body, _, _, stop in
            if body.categoryBitMask & PhysicsCategory.wall != 0 {
                blocked = true
                stop.pointee = true
            }
        }
        return !blocked
    }

    func fire(from c: Character, direction: CGVector, now: TimeInterval) {
        combat.tryFire(from: c, direction: direction, now: now)
    }

    func randomPointInZone() -> CGPoint {
        let r = zone.currentRadius * 0.85 * sqrt(CGFloat.random(in: 0...1))
        let angle = CGFloat.random(in: 0...(2 * .pi))
        return zone.center + CGVector(angle: angle) * r
    }

    // MARK: Contacts (projectiles)

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA, b = contact.bodyB
        let proj: SKPhysicsBody
        let other: SKPhysicsBody
        if isProjectile(a) { proj = a; other = b }
        else if isProjectile(b) { proj = b; other = a }
        else { return }

        guard let projNode = proj.node, projNode.parent != nil else { return }
        let hit = projNode.position

        if other.categoryBitMask & PhysicsCategory.wall != 0 {
            FX.impactSparks(at: hit, in: self)
            projNode.removeFromParent()
            return
        }
        if let otherNode = other.node,
           let character = nodeToCharacter[ObjectIdentifier(otherNode)],
           character.isAlive {
            character.takeDamage(GameConfig.projectileDamage)
            FX.impactSparks(at: hit, in: self)
            triggerShake(5)
            projNode.removeFromParent()
        }
    }

    private func isProjectile(_ body: SKPhysicsBody) -> Bool {
        body.categoryBitMask & (PhysicsCategory.projectilePlayer | PhysicsCategory.projectileBot) != 0
    }

    // MARK: Entrées tactiles

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesBegan(touches, in: cam)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesMoved(touches, in: cam)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesEnded(touches)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        input.touchesEnded(touches)
    }
}
