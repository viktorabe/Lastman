# Lastman

Lastman is an offline iOS battle royale prototype built in Swift. It is a
minimal black-and-white top-down twin-stick shooter: one human player enters an
arena against bots, hides in bushes, survives a shrinking safe zone, and wins by
being the last character standing.

The project is designed as a compact, playable v1 with no network layer, no
accounts, and no multiplayer dependency. The priority is game feel: responsive
movement, readable combat, simple bot behavior, and satisfying visual feedback.

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

The game intentionally keeps v1 narrow: one arena, one player, offline bots,
simple physics, and no progression systems. More advanced ideas such as local
multiplayer, multiple maps, character abilities, and progression are left for a
future version after the core loop feels fun.

## Running Locally

1. Open `Lastman.xcodeproj` in Xcode.
2. Select the iOS target.
3. Build and run on the simulator or a physical iPhone.

