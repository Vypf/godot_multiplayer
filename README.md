# godot-multiplayer

Addon Godot 4 pour créer des jeux multijoueurs avec architecture lobby/room.

## Fonctionnalités

- **Lobby Server** : Serveur central qui gère les connexions et spawn les game servers
- **Game Instance** : Wrapper WebSocket pour les serveurs de jeu
- **Lobby Client** : Connexion côté joueur au lobby
- **Lobby Manager** : Gestion des slots joueurs et coordination du démarrage
- **Waiting Room** : UI de salle d'attente avec système Ready
- **Player Spawner** : Spawn des joueurs avec autorité multiplayer correcte

## Installation

### Option recommandée : Téléchargement

1. Télécharger la [dernière release](https://github.com/Vypf/godot_multiplayer/releases) ou cloner le repository
2. Copier le dossier `addons/godot_multiplayer/` dans votre projet

### Option avancée : Git Submodule

Utile si vous souhaitez contribuer à l'addon ou le modifier en parallèle de votre jeu :

```bash
git submodule add https://github.com/Vypf/godot_multiplayer.git addons/godot_multiplayer
```

Pour cloner un projet utilisant le submodule :
```bash
git clone --recursive <url-du-projet>
# ou après un clone classique :
git submodule update --init --recursive
```

## Configuration rapide avec Claude Code

Si vous utilisez [Claude Code](https://claude.ai/code), un **skill** est disponible pour configurer automatiquement votre projet :

1. Assurez-vous que le submodule est installé (voir ci-dessus)
2. Dans Claude Code, demandez simplement :
   > "Configure mon projet Godot avec le multijoueur"

   ou

   > "Ajoute le support multijoueur à mon jeu"

Le skill `setup-multiplayer-project` créera automatiquement tous les fichiers nécessaires :
- Scripts GDScript (`config.gd`, `game.gd`, `local_instance_manager.gd`)
- Scène principale (`game.tscn`)
- Configuration Docker et CI/CD GitHub Actions
- Déploiement web sur GitHub Pages

## Configuration manuelle

### 1. Activer le plugin

Dans `project.godot` :
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_multiplayer/plugin.cfg")
```

### 2. Architecture

Le système supporte 3 modes de runtime :

| Mode | Description | Argument |
|------|-------------|----------|
| **PLAYER** | Client joueur avec UI | (défaut) |
| **room** | Serveur de jeu headless | `server_type=room` |
| **lobby** | Serveur lobby orchestrateur | `server_type=lobby` |

### 3. Composants principaux

#### LobbyServer
Orchestre la création de game servers. Écoute les demandes de création/join de room et spawn des processus Godot headless.

#### GameInstance
Gère la connexion WebSocket d'une instance de jeu (serveur ou client).

#### LobbyClient
Permet à un client de se connecter au lobby pour créer ou rejoindre une room.

#### LobbyManager
Synchronise l'état des joueurs dans une room (slots, ready state, démarrage).

#### PlayerSpawner
Étend `MultiplayerSpawner` pour gérer le spawn des joueurs avec la bonne autorité.

## Ports par défaut

| Service | Port |
|---------|------|
| Lobby | 17018 |
| Game servers | 18000-19000 (dynamique) |

## Documentation

- [Arguments de configuration](.claude/skills/setup-multiplayer-project/reference/arguments.md)
- [Troubleshooting](.claude/skills/setup-multiplayer-project/reference/troubleshooting.md)

## Licence

MIT
