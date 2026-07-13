# Lastman

Lastman is a fast iOS battle royale built in Swift. It is a
minimal black-and-white top-down twin-stick shooter: one human player enters an
arena against bots, hides in bushes, survives a shrinking safe zone, and wins by
being the last character standing.

Matches remain fully playable offline. Game Center adds an optional social layer
for daily leaderboards, while local progression, missions, weapon mastery, and
shareable scores give every run a purpose. The priority remains game feel:
responsive movement, readable combat, fair bots, and satisfying feedback.

## Features

- Single-player battle royale against offline bots.
- Twin-stick controls: left stick to move, right stick to aim and auto-fire.
- Health, projectile damage, hit feedback, death effects, and match results.
- Bushes for hiding, occlusion, and reveal behavior.
- Shrinking safe zone with damage outside the circle.
- Bot AI based on state-machine behavior: wander, chase, attack, flee, avoid
  zone, and dead.
- Menu, settings, match, and result screens.
- Adjustable difficulty and bot count.
- Guided first match with one-thumb auto-aim and optional precision aiming.
- A deterministic daily challenge with rotating rules and a shared score.
- Local levels, streaks, daily missions, weapon mastery, and cosmetic colors.
- Game Center leaderboard and friend challenge sharing.
- Procedural sound design with independent sound and haptics settings.

## Tech Stack

- Swift
- SpriteKit
- GameplayKit
- iOS
- Xcode

## Project Structure

```text
Lastman Shared/
  Bot.swift
  BotBrain.swift
  BushSystem.swift
  Character.swift
  CombatSystem.swift
  FX.swift
  GameConfig.swift
  GameScene.swift
  InputController.swift
  Joystick.swift
  MenuScene.swift
  Player.swift
  ResultScene.swift
  SettingsScene.swift
  ZoneSystem.swift
Lastman iOS/
  AppDelegate.swift
  GameViewController.swift
  SceneDelegate.swift
SPEC.md
```

## Development Notes

The game intentionally keeps real-time play narrow: one arena, one player and
offline bots. The daily seed changes the weapon, difficulty, population and zone
pressure without requiring a server-backed match. Real-time multiplayer remains
out of scope until the daily loop proves strong retention.

## Running Locally

1. Open `Lastman.xcodeproj` in Xcode.
2. Select the iOS target.
3. Build and run on the simulator or a physical iPhone.
