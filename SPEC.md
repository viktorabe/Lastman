# SPEC.md — Stickman Battle Royale (offline)

## 1. Vue d'ensemble

Twin-stick shooter en battle royale, vue du dessus, **un seul joueur humain contre des bots, 100 % offline**. Le joueur incarne un stickman dans une arène fermée, se déplace au joystick gauche, vise et tire au joystick droit (auto-fire), se cache dans des buissons, et survit à une zone safe qui rétrécit. Dernier debout gagne.

Pitch en une phrase : un Brawl Stars minimaliste en noir et blanc, solo contre des bots, sans réseau.

Plateforme : iOS uniquement. Swift + SpriteKit + GameplayKit, Xcode. Pas de moteur tiers.

## 2. Scope v1 (lire en premier)

**DANS la v1 :**
- 1 arène unique (layout fixe, pas de génération procédurale)
- 1 joueur humain + N bots (N réglable, défaut 5)
- Déplacement twin-stick + tir auto
- Système de PV et de dégâts
- Buissons (occlusion)
- Zone safe qui rétrécit + dégâts hors-zone
- FSM des bots offline
- Écrans : menu → réglages → match → victoire/défaite
- Réglage de difficulté

**HORS scope v1 (ne pas construire) :**
- Tout réseau / multijoueur / Game Center / MultipeerConnectivity
- Plusieurs cartes
- Roster de personnages, capacités spéciales, ultimates
- Progression, déblocages, monnaie, monétisation
- Gestion de munitions / rechargement (auto-fire à cadence fixe en v1)
- Pathfinding complexe / navigation mesh (steering simple suffit)
- Animation squelettique (sprite-swap + SKAction en v1)
- Son musique élaborée (SFX minimaux suffisent)

Règle d'or : aucun système n'est ajouté tant que le précédent n'est pas jouable et fun **sans** lui.

## 3. Stack technique

- **SpriteKit** : rendu, scene graph, `SKPhysicsBody` (collisions murs / projectiles / corps), `SKEmitterNode` (particules), `SKAction` (animations et juice).
- **GameplayKit** : `GKStateMachine` + `GKState` pour la FSM des bots. Steering simple à la main (vecteur vers cible, clamp de vitesse) ; `GKAgent2D`/`GKGoal` optionnel plus tard si besoin. Pas de pathfinding en v1.
- **Catégories de physique** (bitmask) : `player`, `bot`, `projectilePlayer`, `projectileBot`, `wall`, `bushSensor`, `zoneSensor`.

Note Claude Code : viser la séparation logique vs rendu. Le state du jeu (positions, PV, état zone) ne doit pas vivre uniquement dans les nodes. Une couche `GameState` / entités, et les `SKNode` ne sont que la représentation visuelle.

## 4. Orientation et contrôles

- **Orientation : portrait.** Deux pouces en bas de l'écran, joystick gauche et droit dans les coins inférieurs. (Décision à valider en playtest ; bascule possible en paysage si ça gêne.)
- **Joystick gauche (déplacement)** : analogique, 360°, vitesse proportionnelle à l'amplitude. Zone tactile flottante (le joystick apparaît là où le pouce se pose dans le quart inférieur gauche).
- **Joystick droit (tir)** : vise dans la direction poussée ET déclenche l'auto-fire tant qu'il est tenu. Relâché = pas de tir. Pas de bouton de tir séparé.
- Pas de tap-to-move, pas de gyroscope.

## 5. Boucle de jeu et états

### États applicatifs (méta)
`Menu → Settings → Match → Result → (retour) Menu`

- **Menu** : titre, bouton Jouer, bouton Réglages.
- **Settings** : nombre de bots, difficulté. Persisté localement (UserDefaults).
- **Match** : la partie elle-même.
- **Result** : Victoire (dernier debout) ou Défaite (mort), avec rang (#1 à #N+1) et bouton Rejouer / Menu.

### États de match (interne)
`Countdown → Active → SuddenDeath(optionnel) → Ended`

- **Countdown** : 3-2-1, spawns placés, contrôles bloqués.
- **Active** : jeu en cours, zone qui se referme par paliers.
- **Ended** : un seul survivant (ou le joueur est mort), transition vers Result.

## 6. Systèmes

### 6.1 Déplacement
- Vitesse de base : ~180 pt/s (à tuner). Identique joueur et bots par défaut.
- Collisions murs via `SKPhysicsBody`, corps des personnages = cercle.
- Pas d'inertie excessive : réactif, léger easing à l'arrêt. **Le feel du déplacement est la priorité n°1, à polir avant tout le reste.**

### 6.2 Tir et combat
- **Cadence** : 1 projectile / 0.35 s tant que le joystick droit est tenu (à tuner).
- **Projectile** : node physique, vitesse ~500 pt/s, portée max ~350 pt puis despawn, dégâts = 20.
- **PV** : 100 par personnage. Mort à 0.
- Collision projectile→personnage : dégâts + flash + étincelles + despawn projectile. Un projectile ne touche pas son tireur.
- Pas de munitions ni de rechargement en v1 (cadence fixe seulement).
- Régénération de PV : optionnelle, off par défaut en v1.

### 6.3 Buissons
- Zones (`bushSensor`) sans collision physique, juste détection de chevauchement.
- Un personnage **à l'intérieur** d'un buisson est *caché* : alpha réduit (~0.15) du point de vue des autres, et **non ciblable par les bots**.
- **Révélé** si : il tire (révélé ~1 s), OU un ennemi entre dans le même buisson / passe sous une distance seuil (~60 pt).
- Le joueur voit toujours son propre stickman normalement.

### 6.4 Zone / battle royale
- Zone safe = cercle centré (centre fixe ou légèrement aléatoire). Rayon initial couvre toute l'arène.
- **Paliers de rétrécissement** : ex. toutes les 20 s, le rayon cible se réduit (100% → 70% → 45% → 25% → 10% → point). Transition animée sur quelques secondes entre deux paliers.
- **Hors zone** : dégâts de poison ~5 PV/s, tint visuel (assombrissement + voile coloré au sol hors zone).
- Bord de zone visible en permanence (cercle net).
- Fin de match : il ne reste qu'un personnage vivant.

## 7. Les bots — FSM (cœur du jeu)

Chaque bot possède sa propre `GKStateMachine`. La perception et la difficulté sont les leviers qui rendent les bots crédibles sans tricher.

### 7.1 Perception
- **Rayon de vision** : ~400 pt. Au-delà, le bot ne « voit » rien.
- **Occlusion buisson** : une cible cachée dans un buisson n'est pas perçue (sauf si elle est révélée, cf. 6.3).
- **Mémoire** : si le bot perd sa cible de vue, il garde la *dernière position connue* pendant ~2 s et s'y dirige, puis repasse en `wander`.
- **Réaction** : entre la perception d'une cible et la première action, délai = `reactionDelay` (paramètre de difficulté).

### 7.2 États

| État | Comportement | 
|------|--------------|
| `idle` | Immobile, scanne. Très court, transitoire au spawn. |
| `wander` | Se déplace vers un point aléatoire dans la zone safe. Cherche une cible en route. |
| `chase` | Cible connue mais hors de portée de tir : avance pour entrer à portée. |
| `attack` | Cible à portée + ligne de vue : strafe (déplacement latéral) tout en tirant vers la cible avec `aimError`. Maintient une distance d'engagement optimale (~250 pt). |
| `flee` | PV < `fleeThreshold` : s'éloigne de la cible, vise un buisson ou de la distance pour se soigner/se cacher. |
| `avoidZone` | **Priorité absolue.** Hors zone safe, ou la zone va se refermer sur sa position : se dirige vers le centre safe. Interrompt tout combat. |
| `dead` | Désactivé, animation de mort, retiré de la logique. |

### 7.3 Transitions

- `idle/wander → chase` : cible perçue (après `reactionDelay`).
- `chase → attack` : cible à portée de tir + ligne de vue dégagée.
- `attack → chase` : cible sort de portée mais reste visible.
- `attack/chase → wander` : cible perdue depuis > 2 s (mémoire épuisée).
- `* → flee` : PV < `fleeThreshold`.
- `flee → wander/chase` : PV remontés au-dessus du seuil OU distance de sécurité atteinte + cible toujours là.
- `* → avoidZone` : position hors zone safe, ou distance au bord < marge ET palier en cours de fermeture. **Override tous les autres états.**
- `avoidZone → wander` : de retour en sécurité dans la zone, marge ok.
- `* → dead` : PV ≤ 0.

### 7.4 Paramètres de difficulté (exposés et réglables)

Un seul curseur de difficulté (Facile / Moyen / Difficile) pilote ces valeurs :

| Paramètre | Facile | Moyen | Difficile |
|-----------|--------|-------|-----------|
| `reactionDelay` (s) | 0.6 | 0.35 | 0.15 |
| `aimError` (écart-type, °) | 18 | 9 | 3 |
| `aggression` (portée d'engagement, pt) | 250 | 350 | 450 |
| `fleeThreshold` (% PV) | 50 | 30 | 15 |
| `botCount` (défaut) | 3 | 5 | 7 |

`aimError` = bruit gaussien ajouté à l'angle de tir. C'est le levier principal de « crédibilité » : un bot précis à 100 % est frustrant, un bot qui rate parfois est humain.

## 8. Direction visuelle

- **Palette** : fond noir / blanc, formes blanches sur fond sombre (ou inverse). Accents de couleur **uniquement pour distinguer les personnages** : le joueur dans une couleur signature, chaque bot dans une teinte distincte ou un gris.
- **Stickman** : trait fin, lisible à petite taille. États à animer (sprite-swap quelques frames) : `idle`, `run`, `aim/shoot`, `hit`, `death`.
- **Juice (priorité, c'est là que naît le plaisir)** :
  - muzzle flash à chaque tir
  - étincelles d'impact (`SKEmitterNode`) sur les hits
  - poof de mort (particules + fade)
  - screen shake léger sur les impacts / morts proches
  - easing (`SKAction` timing curves) sur tout : spawn, hit, transitions
  - feedback de tir reçu : flash blanc sur le corps touché
- **Buissons** : formes douces semi-transparentes, lisibles mais discrètes.
- **Zone** : cercle net pour le bord safe, voile coloré + assombrissement hors zone.

Le stickman pardonne beaucoup : ne pas sur-investir dans le rig, mettre l'effort dans les SKAction et les particules.

## 9. Architecture du code (suggestion)

```
GameScene (SKScene)
├── GameState            // PV, positions logiques, état zone, liste des vivants
├── InputController      // 2 joysticks virtuels → intents (move vec, aim vec)
├── Entities
│   ├── Character (base) // joueur + bots, PV, node, physics body
│   ├── PlayerController // mappe les intents joueur
│   └── BotBrain         // GKStateMachine + perception + difficulté
├── Systems
│   ├── CombatSystem     // tir, projectiles, dégâts
│   ├── BushSystem       // occlusion / révélation
│   └── ZoneSystem       // rétrécissement, dégâts hors-zone
└── FX                   // particules, screen shake, helpers SKAction
```

Garder `GameState` comme source de vérité ; les `SKNode` reflètent l'état, ne le portent pas seuls.

## 10. Ordre de construction (jalons, chacun jouable)

1. **Arène + déplacement** : 1 stickman, joystick gauche, collisions murs. *Polir le feel ici avant tout.*
2. **Tir** : joystick droit + auto-fire, projectiles physiques, PV, barres de vie. Boucle de combat contre une cible factice immobile.
3. **Un bot** : FSM minimale (`wander → chase → attack`), bête mais fonctionnel. Le morceau le plus neuf — prendre son temps.
4. **Buissons** : occlusion + révélation, côté joueur et bots.
5. **Zone** : rétrécissement par paliers + dégâts hors-zone. On a un vrai BR.
6. **N bots + difficulté** : monter à plusieurs bots, brancher les paramètres de difficulté, ajouter `flee` et `avoidZone`.
7. **Polish anim + juice** : états du stickman, particules, screen shake, easing, SFX.
8. **Shell** : menu, réglages, écran de résultat avec rang, persistance.
9. **Signing + App Store** (déjà maîtrisé).

## 11. Constantes à exposer (pour tuner vite)

Regrouper dans un seul fichier `GameConfig.swift` :
`playerSpeed, projectileSpeed, projectileRange, projectileDamage, fireInterval, maxHP, poisonDPS, visionRadius, engageDistance, zoneStages[], zoneShrinkInterval, reactionDelay, aimError, aggression, fleeThreshold, botCount`.

## 12. v2+ (notées, pas construites)

Multi-appareils local (MultipeerConnectivity), plusieurs cartes, capacités/personnages, rig squelettique, munitions/rechargement, pathfinding GameplayKit, régénération de PV, progression. À ne regarder qu'une fois la v1 fun et testée en soirée.
