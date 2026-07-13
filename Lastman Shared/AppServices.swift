//
//  AppServices.swift
//  Lastman
//
//  Boucle meta : défi quotidien, progression, Game Center, partage et son.
//

import AVFoundation
import GameKit
import SpriteKit
import UIKit

// MARK: - Défi quotidien

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

enum DailyModifier: Int, CaseIterable, Codable {
    case classic
    case closingCircle
    case sharpshooter
    case crowded

    var title: String {
        switch self {
        case .classic: return "CLASSIQUE"
        case .closingCircle: return "ZONE EXPRESS"
        case .sharpshooter: return "PRÉCISION"
        case .crowded: return "MÊLÉE"
        }
    }

    var zonePressureMultiplier: CGFloat {
        self == .closingCircle ? 0.72 : 1
    }
}

struct DailyChallenge: Equatable {
    let dayKey: String
    let seed: UInt64
    let weaponStyle: WeaponStyle
    let difficulty: Difficulty
    let botCount: Int
    let modifier: DailyModifier

    static var today: DailyChallenge {
        challenge(for: dayKey(for: Date()))
    }

    static func challenge(for dayKey: String) -> DailyChallenge {
        let seed = stableSeed(for: dayKey)
        var generator = SeededGenerator(seed: seed)
        let modifier = DailyModifier.allCases[Int.random(in: 0..<DailyModifier.allCases.count, using: &generator)]
        let weapon: WeaponStyle
        switch modifier {
        case .sharpshooter:
            weapon = .sniper
        default:
            weapon = WeaponStyle.allCases[Int.random(in: 0..<WeaponStyle.allCases.count, using: &generator)]
        }
        let difficulty: Difficulty = Bool.random(using: &generator) ? .medium : .hard
        let bots = modifier == .crowded ? 9 : Int.random(in: 6...8, using: &generator)
        return DailyChallenge(
            dayKey: dayKey,
            seed: seed,
            weaponStyle: weapon,
            difficulty: difficulty,
            botCount: bots,
            modifier: modifier
        )
    }

    static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func stableSeed(for value: String) -> UInt64 {
        value.utf8.reduce(0xcbf29ce484222325) { partial, byte in
            (partial ^ UInt64(byte)) &* 0x100000001b3
        }
    }

    var shortDate: String {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3 else { return dayKey }
        return "\(parts[2])/\(parts[1])"
    }
}

enum MatchMode: Equatable {
    case standard
    case tutorial
    case daily(DailyChallenge)

    var dailyChallenge: DailyChallenge? {
        guard case .daily(let challenge) = self else { return nil }
        return challenge
    }

    var title: String {
        switch self {
        case .standard: return "PARTIE LIBRE"
        case .tutorial: return "PREMIÈRE PARTIE"
        case .daily(let challenge): return "DÉFI \(challenge.shortDate) · \(challenge.modifier.title)"
        }
    }
}

// MARK: - Progression locale

struct DailyStats: Codable {
    var bestScore = 0
    var runs = 0
    var wins = 0
    var kills = 0
    var pickups = 0
}

struct PlayerProfile: Codable {
    var xp = 0
    var matches = 0
    var victories = 0
    var dailyStreak = 0
    var lastDailyKey: String?
    var dailyStats: [String: DailyStats] = [:]
    var weaponXP: [String: Int] = [:]
    var claimedMissionIDs: [String] = []
}

struct MatchProgressResult {
    let xpEarned: Int
    let level: Int
    let didLevelUp: Bool
    let isNewDailyBest: Bool
}

enum ProgressionStore {
    private static let profileKey = "lastman.playerProfile.v2"
    private static let firstMatchKey = "lastman.firstMatchCompleted"

    static var hasCompletedFirstMatch: Bool {
        get { UserDefaults.standard.bool(forKey: firstMatchKey) }
        set { UserDefaults.standard.set(newValue, forKey: firstMatchKey) }
    }

    static var profile: PlayerProfile {
        get {
            guard let data = UserDefaults.standard.data(forKey: profileKey),
                  let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) else {
                return PlayerProfile()
            }
            return profile
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    static var level: Int { level(forXP: profile.xp) }

    static var playerColor: SKColor {
        switch level {
        case 1...2: return SKColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1)
        case 3...4: return SKColor(red: 0.36, green: 0.95, blue: 0.62, alpha: 1)
        case 5...7: return SKColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 1)
        default: return SKColor(red: 0.76, green: 0.46, blue: 1.0, alpha: 1)
        }
    }

    static func bestScore(for dayKey: String) -> Int {
        profile.dailyStats[dayKey]?.bestScore ?? 0
    }

    static func missionText(for dayKey: String) -> String {
        let stats = profile.dailyStats[dayKey] ?? DailyStats()
        return "MISSIONS  \(min(stats.runs, 3))/3 PARTIES · \(min(stats.kills, 5))/5 KILLS · \(min(stats.pickups, 4))/4 BONUS"
    }

    static func record(_ summary: MatchSummary) -> MatchProgressResult {
        var current = profile
        let oldLevel = level(forXP: current.xp)
        var xpEarned = 35
            + summary.playerKills * 24
            + summary.playerPickupsCollected * 8
            + (summary.victory ? 120 : 0)
            + min(80, Int(summary.survivalTime / 2))

        current.matches += 1
        if summary.victory { current.victories += 1 }
        current.weaponXP[String(summary.weaponStyle.rawValue), default: 0] += xpEarned

        var newDailyBest = false
        if let challenge = summary.matchMode.dailyChallenge {
            var stats = current.dailyStats[challenge.dayKey] ?? DailyStats()
            newDailyBest = summary.score > stats.bestScore
            stats.bestScore = max(stats.bestScore, summary.score)
            stats.runs += 1
            stats.wins += summary.victory ? 1 : 0
            stats.kills += summary.playerKills
            stats.pickups += summary.playerPickupsCollected
            current.dailyStats[challenge.dayKey] = stats
            updateStreak(profile: &current, playedDayKey: challenge.dayKey)
            let missions = [
                ("runs", stats.runs >= 3),
                ("kills", stats.kills >= 5),
                ("pickups", stats.pickups >= 4),
            ]
            for (mission, completed) in missions where completed {
                let identifier = "\(challenge.dayKey).\(mission)"
                if !current.claimedMissionIDs.contains(identifier) {
                    current.claimedMissionIDs.append(identifier)
                    xpEarned += 100
                }
            }
        }

        current.xp += xpEarned
        profile = current
        let newLevel = level(forXP: current.xp)
        return MatchProgressResult(
            xpEarned: xpEarned,
            level: newLevel,
            didLevelUp: newLevel > oldLevel,
            isNewDailyBest: newDailyBest
        )
    }

    private static func level(forXP xp: Int) -> Int {
        max(1, Int(sqrt(Double(max(0, xp)) / 180.0)) + 1)
    }

    private static func updateStreak(profile: inout PlayerProfile, playedDayKey: String) {
        guard profile.lastDailyKey != playedDayKey else { return }
        if let last = profile.lastDailyKey,
           let lastDate = date(from: last),
           let playedDate = date(from: playedDayKey) {
            let days = Calendar(identifier: .gregorian).dateComponents([.day], from: lastDate, to: playedDate).day ?? 0
            profile.dailyStreak = days == 1 ? profile.dailyStreak + 1 : 1
        } else {
            profile.dailyStreak = 1
        }
        profile.lastDailyKey = playedDayKey
    }

    private static func date(from dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }
}

enum ChallengeScoring {
    static func score(
        victory: Bool,
        rank: Int,
        total: Int,
        survivalTime: TimeInterval,
        kills: Int,
        damage: CGFloat,
        pickups: Int,
        breakables: Int,
        streak: Int
    ) -> Int {
        let placement = victory ? 5_000 : max(0, total - rank) * 450
        return placement
            + kills * 750
            + Int(damage.rounded()) * 5
            + pickups * 160
            + breakables * 100
            + streak * 240
            + min(1_500, Int(survivalTime * 12))
    }
}

// MARK: - Game Center

final class GameCenterManager: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterManager()
    static let dailyLeaderboardID = "com.viktorabe.lastman.daily"

    private weak var presentingViewController: UIViewController?

    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    func authenticate(from viewController: UIViewController) {
        presentingViewController = viewController
        GKLocalPlayer.local.authenticateHandler = { [weak viewController] authViewController, _ in
            if let authViewController, let viewController {
                viewController.present(authViewController, animated: true)
            }
        }
    }

    func submitDailyScore(_ score: Int, dayKey: String) {
        guard isAuthenticated else { return }
        let context = Int(dayKey.replacingOccurrences(of: "-", with: "")) ?? 0
        GKLeaderboard.submitScore(
            score,
            context: context,
            player: GKLocalPlayer.local,
            leaderboardIDs: [Self.dailyLeaderboardID]
        ) { _ in }
    }

    func showLeaderboards(from viewController: UIViewController?) {
        guard let viewController = viewController ?? presentingViewController else { return }
        let gameCenter = GKGameCenterViewController(state: .leaderboards)
        gameCenter.gameCenterDelegate = self
        viewController.present(gameCenter, animated: true)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

// MARK: - Partage et liens de défi

enum ChallengeLinkStore {
    private static let pendingDayKey = "lastman.pendingChallengeDay"

    static func receive(_ url: URL) {
        guard url.scheme == "lastman", url.host == "daily" else { return }
        let dayKey = url.pathComponents.dropFirst().first ?? DailyChallenge.today.dayKey
        UserDefaults.standard.set(dayKey, forKey: pendingDayKey)
    }

    static func consumeChallenge() -> DailyChallenge? {
        guard let key = UserDefaults.standard.string(forKey: pendingDayKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingDayKey)
        return DailyChallenge.challenge(for: key)
    }
}

enum ShareManager {
    static func share(summary: MatchSummary, from viewController: UIViewController?) {
        guard let viewController else { return }
        let challenge = summary.matchMode.dailyChallenge
        let title = summary.victory ? "DERNIER DEBOUT" : "#\(summary.rank) SUR \(summary.total)"
        let detail = challenge == nil
            ? "J’ai marqué \(summary.score) points sur Lastman."
            : "J’ai marqué \(summary.score) points au défi Lastman du \(challenge!.shortDate). À toi de jouer."
        let image = resultCard(title: title, detail: detail, score: summary.score)
        var items: [Any] = [image, detail]
        if let challenge,
           let url = URL(string: "lastman://daily/\(challenge.dayKey)?score=\(summary.score)") {
            items.append(url)
        } else if let url = URL(string: "https://viktorabe.com/lastman") {
            items.append(url)
        }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = viewController.view
        activity.popoverPresentationController?.sourceRect = CGRect(
            x: viewController.view.bounds.midX,
            y: viewController.view.bounds.midY,
            width: 1,
            height: 1
        )
        viewController.present(activity, animated: true)
    }

    private static func resultCard(title: String, detail: String, score: Int) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        return UIGraphicsImageRenderer(size: size).image { context in
            let canvas = context.cgContext
            UIColor(red: 0.025, green: 0.03, blue: 0.038, alpha: 1).setFill()
            canvas.fill(CGRect(origin: .zero, size: size))

            let cyan = UIColor(red: 0.35, green: 0.82, blue: 1, alpha: 1)
            cyan.setStroke()
            canvas.setLineWidth(18)
            canvas.strokeEllipse(in: CGRect(x: 178, y: 148, width: 724, height: 724))

            draw("LASTMAN", at: CGPoint(x: 540, y: 86), size: 46, color: .white)
            draw(title, at: CGPoint(x: 540, y: 395), size: 70, color: cyan)
            draw("\(score) PTS", at: CGPoint(x: 540, y: 505), size: 112, color: .white)
            draw(detail, at: CGPoint(x: 540, y: 915), size: 34, color: UIColor(white: 1, alpha: 0.72))
        }
    }

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat, color: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let rect = CGRect(x: 70, y: point.y, width: 940, height: size * 2.4)
        text.draw(in: rect, withAttributes: attributes)
    }
}

extension SKScene {
    var hostingViewController: UIViewController? {
        view?.window?.rootViewController
    }
}

// MARK: - Sound design procédural

enum SoundCue {
    case button
    case countdown
    case start
    case shot(WeaponStyle)
    case hit
    case damage
    case kill(Int)
    case victory
    case defeat
}

final class SoundFX {
    static let shared = SoundFX()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0

    private init() {
        for _ in 0..<10 {
            let player = AVAudioPlayerNode()
            players.append(player)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    func play(_ cue: SoundCue) {
        guard GameSettings.soundEnabled else { return }
        if !engine.isRunning { try? engine.start() }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        let buffer = makeBuffer(for: cue)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func makeBuffer(for cue: SoundCue) -> AVAudioPCMBuffer {
        let specification = soundSpecification(for: cue)
        let frameCount = AVAudioFrameCount(format.sampleRate * specification.duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let samples = buffer.floatChannelData?[0] else { return buffer }

        for index in 0..<Int(frameCount) {
            let t = Double(index) / format.sampleRate
            let progress = t / specification.duration
            let frequency = specification.startFrequency
                + (specification.endFrequency - specification.startFrequency) * progress
            let envelope = sin(.pi * min(1, progress)) * pow(max(0, 1 - progress), 0.35)
            let tone = sin(2 * .pi * frequency * t)
            let noise = Double.random(in: -1...1) * specification.noise
            samples[index] = Float((tone * (1 - specification.noise) + noise) * envelope * specification.volume)
        }
        return buffer
    }

    private func soundSpecification(for cue: SoundCue) -> (startFrequency: Double, endFrequency: Double, duration: Double, volume: Double, noise: Double) {
        switch cue {
        case .button: return (520, 620, 0.055, 0.16, 0)
        case .countdown: return (420, 520, 0.12, 0.20, 0)
        case .start: return (380, 920, 0.24, 0.24, 0)
        case .shot(let style):
            switch style {
            case .normal: return (340, 160, 0.085, 0.20, 0.16)
            case .heavy: return (180, 62, 0.18, 0.30, 0.30)
            case .sniper: return (950, 260, 0.13, 0.26, 0.08)
            }
        case .hit: return (760, 250, 0.07, 0.22, 0.22)
        case .damage: return (150, 72, 0.16, 0.27, 0.30)
        case .kill(let streak): return (520 + Double(streak) * 70, 980 + Double(streak) * 80, 0.22, 0.28, 0.06)
        case .victory: return (440, 1_180, 0.75, 0.28, 0)
        case .defeat: return (260, 72, 0.62, 0.24, 0.08)
        }
    }
}
