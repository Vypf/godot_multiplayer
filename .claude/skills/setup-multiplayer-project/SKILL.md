---
name: setup-multiplayer-project
description: Configure un projet Godot avec godot-multiplayer (lobby, rooms, Docker, CI/CD GitHub Actions, client web). Utiliser quand l'utilisateur veut ajouter le multijoueur à son projet Godot.
version: "2.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Configuration d'un projet Godot avec godot-multiplayer

Ce skill configure automatiquement l'addon godot-multiplayer dans un projet Godot pour créer un jeu multijoueur avec :
- Écran de lobby (host/join)
- Salle d'attente avec bouton Ready
- Lancement de partie par l'hôte
- Support développement local et production Docker
- CI/CD GitHub Actions pour publier l'image Docker du serveur sur ghcr.io
- Client web avec déploiement automatique sur GitHub Pages

## Prérequis

- L'addon godot-multiplayer doit être installé comme submodule (voir README de l'addon)
- Un repository GitHub pour le CI/CD

### Prérequis GitHub (pour CI/CD)

1. Activer GitHub Packages : Settings > Actions > General > Workflow permissions > Read and write
2. Pour GitHub Pages : Settings > Pages > Source > GitHub Actions

## Variables à configurer

Demander ces informations à l'utilisateur avant de commencer :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `GAME_NAME` | Identifiant unique du jeu (kebab-case) | `space-chicken` |
| `SERVER_URL` | Domaine de production (sans protocole) | `games.example.com` |
| `PLAYER_SCENE_PATH` | Chemin vers la scène joueur | `res://player/player.tscn` |

## Étapes d'installation

### Étape 1 : Configurer project.godot

Modifier `project.godot` pour :

1. **Définir la scène principale** :
```ini
[application]

run/main_scene="res://game.tscn"
config/server_url=""
config/server_url_production="SERVER_URL"
```

2. **Activer le plugin** :
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_multiplayer/plugin.cfg")
```

3. **Ajouter l'autoload Config** :
```ini
[autoload]

Config="*res://config.gd"
```

**Note** : Les feature tag overrides (ex: `config/server_url.web`) ne fonctionnent pas à runtime (bug Godot #101207). On utilise deux settings séparés et `OS.has_feature("web")` dans le code.

### Étape 2 : Créer les fichiers GDScript

Copier les fichiers templates suivants à la racine du projet :

1. **config.gd** - Parser d'arguments CLI
   - Source : `templates/config.gd`
   - Destination : `res://config.gd`

2. **local_instance_manager.gd** - Gestionnaire de spawn local
   - Source : `templates/local_instance_manager.gd`
   - Destination : `res://local_instance_manager.gd`

3. **game.gd** - Script principal
   - Source : `templates/game.gd`
   - Destination : `res://game.gd`

### Étape 3 : Créer la scène principale

Copier le template de scène :
- Source : `templates/game.tscn`
- Destination : `res://game.tscn`

**Remplacements requis dans game.tscn** :
- `{{GAME_NAME}}` → Nom du jeu (ex: `space-chicken`)
- `{{PLAYER_SCENE_PATH}}` → Chemin de la scène joueur (ex: `res://player/player.tscn`)

### Étape 4 : Configurer Git

1. Copier `.gitignore` :
   - Source : `templates/gitignore`
   - Destination : `.gitignore` (à la racine)

### Étape 5 : Configurer Docker

1. **Dockerfile** (serveur de jeu headless) :
   - Source : `templates/Dockerfile`
   - Destination : `Dockerfile`

2. **Dockerfile.web** (client web avec nginx) :
   - Source : `templates/Dockerfile.web`
   - Destination : `Dockerfile.web`

3. **nginx.web.conf** (headers COOP/COEP pour Godot 4) :
   - Source : `templates/nginx.web.conf`
   - Destination : `nginx.web.conf`

4. **.dockerignore** :
   - Source : `templates/dockerignore`
   - Destination : `.dockerignore`

### Étape 6 : Configurer GitHub Actions

1. Créer le dossier `.github/workflows/`

2. **docker-publish.yml** (publication image serveur sur ghcr.io) :
   - Source : `workflows/docker-publish.yml`
   - Destination : `.github/workflows/docker-publish.yml`

3. **deploy-web.yml** (déploiement client web sur GitHub Pages) :
   - Source : `workflows/deploy-web.yml`
   - Destination : `.github/workflows/deploy-web.yml`

### Étape 7 : Créer le preset d'export Web

Dans Godot :
1. Ouvrir **Project > Export...**
2. Cliquer **Add...** et sélectionner **Web**
3. Nommer le preset exactement **"Web"** (utilisé par les workflows)
4. Sauvegarder (génère `export_presets.cfg`)

## Résumé des fichiers créés

| Fichier | Description |
|---------|-------------|
| `config.gd` | Autoload pour parser les arguments CLI |
| `local_instance_manager.gd` | Gestionnaire de spawn des serveurs locaux |
| `game.gd` | Script principal orchestrant les 3 modes |
| `game.tscn` | Scène principale avec composants multiplayer |
| `.gitignore` | Fichiers à ignorer par Git |
| `Dockerfile` | Image Docker du serveur headless |
| `Dockerfile.web` | Image Docker du client web (nginx) |
| `nginx.web.conf` | Config nginx avec headers COOP/COEP |
| `.dockerignore` | Fichiers à exclure de l'image Docker |
| `export_presets.cfg` | Presets d'export (généré par Godot) |
| `.github/workflows/docker-publish.yml` | CI/CD serveur → ghcr.io |
| `.github/workflows/deploy-web.yml` | CI/CD client → GitHub Pages |

## Test en développement local

### 1. Lancer le lobby server

```bash
godot --headless server_type=lobby environment=development \
    --log_folder=./logs \
    --executable_paths GAME_NAME="/chemin/vers/godot" \
    --paths GAME_NAME="/chemin/vers/projet"
```

### 2. Lancer des clients (2+ fenêtres)

```bash
godot --path . environment=development
```

## Références

- Arguments de configuration : voir `reference/arguments.md`
- Problèmes connus : voir `reference/troubleshooting.md`
