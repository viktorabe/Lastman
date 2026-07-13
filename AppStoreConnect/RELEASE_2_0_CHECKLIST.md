# Lastman 2.0 — configuration de sortie

Le code de l'app est prêt pour ces intégrations, mais les objets App Store Connect
doivent être créés dans le compte Apple avant l'envoi du build.

## Game Center

1. Activer Game Center sur l'App ID `com.viktorabe.Lastman`.
2. Créer un leaderboard récurrent quotidien avec l'identifiant
   `com.viktorabe.lastman.daily`.
3. Format de score : entier, ordre décroissant, valeur minimale `0`.
4. Ajouter les localisations FR `Défi du jour` et EN `Daily Challenge`.
5. Associer le leaderboard à la version 2.0 puis le soumettre à la review.

## Liens de défi

Le schéma `lastman://daily/YYYY-MM-DD?score=1234` fonctionne lorsque l'app est
installée. Pour un lien web universel install-or-open, ajouter ensuite :

- le domaine associé `applinks:viktorabe.com` dans Xcode ;
- un fichier `apple-app-site-association` sur le domaine ;
- une page `/lastman` avec redirection vers l'App Store.

## Page App Store

- Remplacer toutes les anciennes captures : elles ne montrent pas le défi, le
  score, les missions ni le nouveau menu.
- Première capture : `LE BATTLE ROYALE DE 90 SECONDES`.
- Deuxième : `UN NOUVEAU DÉFI CHAQUE JOUR`.
- Troisième : `BATS TES AMIS`.
- Quatrième : `PROGRESSE À CHAQUE PARTIE`.
- Cinquième : `JOUE PARTOUT, MÊME HORS LIGNE`.
- Ajouter une App Preview de 15 à 20 secondes sans écran titre prolongé.
- Tester au moins deux icônes et deux ordres de screenshots avec Product Page
  Optimization.

## Mesure avant lancement large

- Première partie terminée : objectif 80 %.
- Trois parties lancées : objectif 50 %.
- Rétention J1 : objectif interne 35 %.
- Rétention J7 : objectif interne 12 %.
- Partages/défis : objectif interne 5 % des joueurs actifs.
- Vérifier les cohortes par version et source dans App Store Connect Analytics.

## Mise en avant Apple

Envoyer une Featuring Nomination pour la version 2.0 plusieurs semaines avant
la date de sortie, avec l'angle : jeu indépendant français, battle royale
minimaliste, défi social quotidien et gameplay offline.
