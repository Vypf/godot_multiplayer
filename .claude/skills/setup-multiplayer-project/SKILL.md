---
name: setup-multiplayer-project
description: Configure un nouveau projet Godot avec le système multijoueur complet godot-multiplayer. Crée les fichiers config.gd, local_instance_manager.gd, game.gd, game.tscn, Dockerfile, Dockerfile.web et les workflows CI/CD GitHub Actions. Utiliser quand l'utilisateur veut ajouter le multijoueur à son projet Godot.
version: "1.0.0"
---

# Configuration d'un projet Godot avec godot-multiplayer

Ce skill configure automatiquement l'addon godot-multiplayer dans un projet Godot pour créer un jeu multijoueur avec :
- Écran de lobby (host/join)
- Salle d'attente avec bouton Ready
- Lancement de partie par l'hôte
- Support développement local et production Docker
- CI/CD GitHub Actions pour publier l'image Docker du serveur sur ghcr.io
- Client web avec déploiement automatique sur GitHub Pages

## Informations à demander à l'utilisateur

Avant de commencer, demander :
1. **Nom du jeu** (ex: "space-chicken") - utilisé pour identifier le jeu dans le lobby
2. **URL du serveur de production** (ex: "games.example.com") - domaine où sera déployé le jeu
3. **Chemin vers la scène de joueur** (ex: "res://player/player.tscn") - scène instanciée pour chaque joueur

## Étape 1 : Ajouter le submodule godot-multiplayer

```bash
git submodule add https://github.com/Vypf/godot_multiplayer.git addons/godot_multiplayer
```

## Étape 2 : Configurer project.godot

Modifier `project.godot` pour :

1. **Activer le plugin** - ajouter la section `[editor_plugins]` :
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_multiplayer/plugin.cfg")
```

2. **Ajouter l'autoload Config** - dans la section `[autoload]` :
```ini
[autoload]

Config="*res://config.gd"
```

3. **Configurer server_url** - dans la section `[application]` :
```ini
[application]

config/server_url=""
config/server_url_production="{{URL_SERVEUR}}"
```

**Note importante** : Les feature tag overrides (ex: `config/server_url.web`) ne fonctionnent pas à runtime (bug Godot #101207). On utilise donc deux settings séparés et `OS.has_feature("web")` dans le code pour détecter l'environnement.

## Étape 3 : Créer config.gd

Créer le fichier `config.gd` à la racine du projet :

```gdscript
extends Node

var arguments := {}:
    get:
        var parsed_args := {}
        var args = OS.get_cmdline_args()

        for i in range(args.size()):
            var arg = args[i]

            if arg.begins_with("--"):
                var key = arg.trim_prefix("--")

                if "=" in arg:
                    var kv = arg.split("=")
                    key = kv[0].trim_prefix("--")
                    var value = _convert_value(kv[1])
                    _add_argument(parsed_args, key, value)
                elif i + 1 < args.size() and not args[i + 1].begins_with("--"):
                    var value = _convert_value(args[i + 1])
                    _add_argument(parsed_args, key, value)
                else:
                    parsed_args[key] = true
            else:
                if "=" in arg:
                    var kv = arg.split("=")
                    var key = kv[0]
                    var value = _convert_value(kv[1])
                    _add_argument(parsed_args, key, value)

        if not parsed_args.has("environment"):
            var env_environment = OS.get_environment("ENVIRONMENT")
            if env_environment != "":
                parsed_args["environment"] = env_environment

        parsed_args.headless = DisplayServer.get_window_list().size() == 0
        return parsed_args


var is_production: bool:
    get:
        var args = arguments
        if args.has("environment") and args["environment"] == "development":
            return false
        return true


func _add_argument(parsed: Dictionary, key: String, value) -> void:
    if typeof(value) == TYPE_STRING and "=" in value:
        var kv = value.split("=")
        if kv.size() == 2:
            if not parsed.has(key) or typeof(parsed[key]) != TYPE_DICTIONARY:
                parsed[key] = {}
            parsed[key][kv[0]] = _convert_value(kv[1])
    else:
        if not parsed.has(key):
            parsed[key] = value
        elif typeof(parsed[key]) == TYPE_ARRAY:
            parsed[key].append(value)
        else:
            parsed[key] = [parsed[key], value]


func _convert_value(raw: String):
    var lower = raw.to_lower()
    if lower == "true":
        return true
    elif lower == "false":
        return false
    elif raw.is_valid_int():
        return int(raw)
    elif raw.is_valid_float():
        return float(raw)
    return raw
```

## Étape 4 : Créer local_instance_manager.gd

Créer le fichier `local_instance_manager.gd` à la racine du projet :

```gdscript
extends RefCounted
class_name LocalInstanceManager

var _paths: Dictionary = {}
var _executable_paths: Dictionary = {}
var _log_folder: String = ""
var _environment: String = "development"
var _lobby_url: String = ""
var _logger: CustomLogger


func _init(
    paths: Dictionary = {},
    executable_paths: Dictionary = {},
    log_folder: String = "",
    environment: String = "development",
    lobby_url: String = ""
):
    _paths = paths
    _executable_paths = executable_paths
    _log_folder = log_folder
    _environment = environment
    _lobby_url = lobby_url
    _logger = CustomLogger.new("LocalInstanceManager")


func spawn(game: String, code: String, port: int) -> Dictionary:
    var root := _get_root(game)
    var executable_path := _get_executable_path(game)
    var log_path := _get_log_path(code)
    var args := _get_args(code, port)

    args = _add_root_to_args(root, args)
    args = _add_log_path_to_args(log_path, args)
    args = _add_lobby_url_to_args(args)

    _logger.info("Spawning game server: " + executable_path + " " + " ".join(args), "spawn")

    var pid := OS.create_process(executable_path, args)
    if pid == -1:
        var error_msg := "Failed to spawn process for game: " + game
        _logger.error(error_msg, "spawn")
        return {"success": false, "error": error_msg}

    _logger.info("Spawned game server with PID: " + str(pid) + ", code: " + code + ", port: " + str(port), "spawn")
    return {"success": true, "error": "", "pid": pid}


func _get_root(game: String) -> String:
    if _paths.has(game):
        return _paths[game]
    return ProjectSettings.globalize_path("res://")


func _get_executable_path(game: String) -> String:
    if _executable_paths.has(game):
        return _executable_paths[game]
    return OS.get_executable_path()


func _get_log_path(code: String) -> String:
    if _log_folder.is_empty():
        return ""
    var dir := DirAccess.open(_log_folder)
    if dir == null:
        DirAccess.make_dir_recursive_absolute(_log_folder)
    return _log_folder.path_join(code + ".log")


func _get_args(code: String, port: int) -> PackedStringArray:
    return PackedStringArray([
        "--headless",
        "server_type=room",
        "environment=" + _environment,
        "code=" + code,
        "port=" + str(port)
    ])


func _add_log_path_to_args(log_path: String, args: PackedStringArray) -> PackedStringArray:
    if log_path.is_empty():
        return args
    args.append("log_path=" + log_path)
    return args


func _add_root_to_args(root: String, args: PackedStringArray) -> PackedStringArray:
    if root.is_empty():
        return args
    args.insert(0, "--path")
    args.insert(1, root)
    return args


func _add_lobby_url_to_args(args: PackedStringArray) -> PackedStringArray:
    if _lobby_url.is_empty():
        return args
    args.append("--lobby_url=" + _lobby_url)
    return args
```

## Étape 5 : Créer game.gd

Créer le fichier `game.gd` à la racine. Remplacer `{{NOM_DU_JEU}}` par le nom du jeu :

```gdscript
extends Node2D
class_name Game

@onready var game_instance: GameInstance = %GameInstance
@onready var lobby_client: LobbyClient = %LobbyClient
@onready var online_multiplayer_screen: OnlineMultiplayerScreen = %OnlineMultiplayerScreen
@onready var lobby_manager: LobbyManager = %LobbyManager
@onready var waiting_room: WaitingRoom = %WaitingRoom
@onready var player_spawner: PlayerSpawner = %PlayerSpawner
@onready var lobby_server: LobbyServer = %LobbyServer
@onready var level = %Level

const TYPES := {
    "PLAYER": "PLAYER",
    "SERVER": "room",
    "LOBBY": "lobby"
}

var type: String:
    get:
        return Config.arguments.get("server_type", TYPES.PLAYER)

const LOBBY_PORT = 17018

## Server URL - in web exports, uses the production URL from ProjectSettings
## Bug workaround: feature tag overrides don't work at runtime (godotengine/godot#101207)
var server_url: String:
    get:
        if OS.has_feature("web"):
            return ProjectSettings.get_setting("application/config/server_url_production", "")
        return ProjectSettings.get_setting("application/config/server_url", "")

## Returns true if server_url is configured (via feature tag in export)
var is_production: bool:
    get:
        return not server_url.is_empty()


func get_game_instance_url(lobby_info: LobbyInfo) -> String:
    if is_production:
        return "wss://" + server_url + "/" + lobby_info.code
    return "ws://localhost:" + str(lobby_info.port)


func get_lobby_manager_url() -> String:
    if Config.arguments.has("lobby_url"):
        return Config.arguments["lobby_url"]
    if is_production:
        return "wss://" + server_url + "/lobby"
    return "ws://localhost:" + str(LOBBY_PORT)


func _ready():
    if type == TYPES.PLAYER:
        _setup_player()
    elif type == TYPES.SERVER:
        _setup_server()
    elif type == TYPES.LOBBY:
        _setup_lobby()


func _setup_player():
    _set_window_title(TYPES.PLAYER)

    waiting_room.on_ready.connect(func(peer_id):
        lobby_manager.ready_peer(peer_id)
    )
    waiting_room.on_start_clicked.connect(func():
        lobby_manager.start()
    )
    lobby_manager.on_slots_update.connect(func(slots):
        waiting_room.peer_id = multiplayer.get_unique_id()
        waiting_room.slots = slots
    )

    game_instance.code_received.connect(func(_code):
        hide_screen(online_multiplayer_screen)
        waiting_room.show()
    )

    online_multiplayer_screen.on_lobby_joined.connect(func(lobby_info: LobbyInfo):
        game_instance.create_client(get_game_instance_url(lobby_info))
    )

    lobby_client.join(get_lobby_manager_url())


func _setup_server():
    _set_window_title(TYPES.SERVER)
    hide_screen(online_multiplayer_screen)

    lobby_manager.on_game_start_requested.connect(func(slots):
        player_spawner.spawn_players(slots)
        # Ajouter ici la logique de démarrage du niveau si nécessaire
    )

    var port = Config.arguments.get("port", null)
    var code = Config.arguments.get("code", null)

    if port == null or code == null:
        print("Can't start game instance because port or code is missing.")
        return

    game_instance.create_server(port, code)
    var info = LobbyInfo.new()
    info.port = int(port)
    info.code = code
    info.pId = OS.get_process_id()
    lobby_client.lobby_info = info
    lobby_client.join(get_lobby_manager_url())


func _setup_lobby():
    _set_window_title(TYPES.LOBBY)
    hide_screen(online_multiplayer_screen)

    var instance_manager = LocalInstanceManager.new(
        Config.arguments.get("paths", {}),
        Config.arguments.get("executable_paths", {}),
        Config.arguments.get("log_folder", ""),
        Config.arguments.get("environment", "development"),
        Config.arguments.get("lobby_url", "")
    )
    lobby_server._instance_manager = instance_manager
    lobby_server.start(Config.arguments.get("port", LOBBY_PORT))


func hide_screen(screen: Control):
    screen.hide()
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.set_process(false)
    screen.set_process_input(false)


func _set_window_title(title: String):
    var window = get_window()
    if window:
        window.title = title
```

## Étape 6 : Créer game.tscn

Créer le fichier `game.tscn`. Remplacer `{{NOM_DU_JEU}}` et `{{PLAYER_SCENE_PATH}}` :

```
[gd_scene load_steps=9 format=3]

[ext_resource type="Script" path="res://game.gd" id="1_game"]
[ext_resource type="PackedScene" path="res://addons/godot_multiplayer/ui/online_multiplayer_screen.tscn" id="2_lobby"]
[ext_resource type="PackedScene" path="res://addons/godot_multiplayer/ui/waiting_room.tscn" id="3_waiting"]
[ext_resource type="Script" path="res://addons/godot_multiplayer/game/game_instance.gd" id="4_instance"]
[ext_resource type="Script" path="res://addons/godot_multiplayer/lobby/lobby_client.gd" id="5_client"]
[ext_resource type="Script" path="res://addons/godot_multiplayer/lobby/lobby_manager.gd" id="6_manager"]
[ext_resource type="Script" path="res://addons/godot_multiplayer/lobby/lobby_server.gd" id="7_server"]
[ext_resource type="Script" path="res://addons/godot_multiplayer/game/player_spawner.gd" id="8_spawner"]

[node name="Game" type="Node2D"]
script = ExtResource("1_game")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="OnlineMultiplayerScreen" parent="CanvasLayer" node_paths=PackedStringArray("lobby_client") instance=ExtResource("2_lobby")]
unique_name_in_owner = true
lobby_client = NodePath("../../LobbyClient")

[node name="WaitingRoom" parent="CanvasLayer" instance=ExtResource("3_waiting")]
unique_name_in_owner = true
visible = false

[node name="GameInstance" type="Node" parent="."]
unique_name_in_owner = true
script = ExtResource("4_instance")

[node name="LobbyClient" type="Node" parent="."]
unique_name_in_owner = true
script = ExtResource("5_client")
game = "{{NOM_DU_JEU}}"

[node name="LobbyManager" type="Node" parent="."]
unique_name_in_owner = true
script = ExtResource("6_manager")

[node name="LobbyServer" type="Node" parent="."]
unique_name_in_owner = true
script = ExtResource("7_server")

[node name="Level" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="PlayerSpawner" type="MultiplayerSpawner" parent="Level"]
unique_name_in_owner = true
script = ExtResource("8_spawner")
player_scene_path = "{{PLAYER_SCENE_PATH}}"
spawn_root = NodePath("..")

[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(0.5, 0.5)
```

## Étape 7 : Mettre à jour la scène principale dans project.godot

Dans la section `[application]` de `project.godot`, définir la scène principale :

```ini
[application]

run/main_scene="res://game.tscn"
```

## Étape 8 : Configurer .gitignore

Créer ou mettre à jour `.gitignore` :

```gitignore
# Godot 4+ specific ignores
.godot/
.nomedia

# Godot-specific ignores
.import/
export.cfg
export_credentials.cfg

# Imported translations
*.translation

# Mono-specific ignores
.mono/
data_*/
mono_crash.*.json

# Local development
executables/
logs/

# Claude
.claude/
CLAUDE.md
```

## Étape 9 : Créer le Dockerfile (serveur de jeu)

Créer `Dockerfile` à la racine. Adapter `GODOT_VERSION` si nécessaire :

```dockerfile
# Stage 1: Download Godot headless
FROM ubuntu:22.04 AS godot-download

ARG GODOT_VERSION=4.5-stable

RUN apt-get update && \
    apt-get install -y wget unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip && \
    unzip Godot_v${GODOT_VERSION}_linux.x86_64.zip && \
    chmod +x Godot_v${GODOT_VERSION}_linux.x86_64

# Stage 2: Runtime image
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y \
    libstdc++6 \
    ca-certificates \
    libfontconfig1 \
    libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=godot-download /tmp/Godot_v4.5-stable_linux.x86_64 /usr/local/bin/godot

WORKDIR /app
COPY --chown=root:root . /app/

RUN rm -rf /app/executables /app/logs /app/.git
RUN mkdir -p /app/logs

# Import des assets Godot - génère .godot/imported/ et .godot/uid_cache.bin
# IMPORTANT: Utiliser --import au lieu de --editor --quit-after 2
# car seul --import génère le fichier uid_cache.bin nécessaire au runtime
# (voir godotengine/godot#107695)
RUN /usr/local/bin/godot --headless --path /app --import || true

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/godot", "--headless", "--path", "/app"]
CMD ["server_type=room"]
```

## Étape 10 : Créer .dockerignore

Créer `.dockerignore` :

```dockerignore
# Godot generated files
# IMPORTANT: Exclure .godot/ pour simuler l'environnement CI (pas de cache local)
# Cela garantit que l'image Docker est identique en local et en CI
.godot/
.import/
*.translation

# Development files
.git/
.gitignore
.gitmodules
.gitattributes

# Executables
executables/

# Logs
logs/
*.log

# Documentation
*.md

# Docker files
Dockerfile
Dockerfile.web
.dockerignore
docker-compose.yml
nginx.web.conf
```

## Étape 11 : Créer le workflow GitHub Actions

Créer le dossier et fichier `.github/workflows/docker-publish.yml` :

```yaml
name: Build and Publish Docker Image

on:
  push:
    branches:
      - main
    tags:
      - 'v*'
  pull_request:
    branches:
      - main
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          # IMPORTANT: Désactiver le cache pour que les changements de submodules soient pris en compte
          no-cache: true
          platforms: linux/amd64

      - name: Image digest
        run: echo ${{ steps.meta.outputs.digest }}
```

## Étape 12 : Créer Dockerfile.web (client web)

Créer `Dockerfile.web` pour builder le client web avec nginx :

```dockerfile
# Stage 1: Build web export using godot-ci
FROM barichello/godot-ci:4.5 AS builder

WORKDIR /game
COPY . .

# Import assets first (--import génère uid_cache.bin)
RUN godot --headless --path /game --import || true

# Export web build
RUN mkdir -p /game/build/web && \
    godot --headless --verbose --path /game --export-release "Web" /game/build/web/index.html

# Stage 2: Nginx to serve the web build
FROM nginx:alpine

# Copy nginx config with required headers for Godot
COPY nginx.web.conf /etc/nginx/conf.d/default.conf

# Copy the web build
COPY --from=builder /game/build/web /usr/share/nginx/html

EXPOSE 80
```

## Étape 13 : Créer nginx.web.conf

Créer `nginx.web.conf` avec les headers COOP/COEP requis par Godot 4 :

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Required headers for Godot 4 web exports (SharedArrayBuffer support)
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proper MIME types for Godot web exports
    location ~ \.wasm$ {
        add_header Content-Type application/wasm;
        add_header Cross-Origin-Opener-Policy "same-origin" always;
        add_header Cross-Origin-Embedder-Policy "require-corp" always;
    }

    location ~ \.js$ {
        add_header Content-Type application/javascript;
        add_header Cross-Origin-Opener-Policy "same-origin" always;
        add_header Cross-Origin-Embedder-Policy "require-corp" always;
    }
}
```

## Étape 14 : Créer le workflow GitHub Pages

Créer `.github/workflows/deploy-web.yml` pour déployer automatiquement sur GitHub Pages :

```yaml
name: Deploy Web Client to GitHub Pages

on:
  push:
    branches:
      - main
  workflow_dispatch:

# Sets permissions of the GITHUB_TOKEN to allow deployment to GitHub Pages
permissions:
  contents: read
  pages: write
  id-token: write

# Allow only one concurrent deployment
concurrency:
  group: "pages"
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: barichello/godot-ci:4.5

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup export templates
        run: |
          # GitHub Actions uses /github/home as HOME, but templates are in /root/
          mkdir -p ~/.local/share/godot/export_templates/4.5.stable
          cp -r /root/.local/share/godot/export_templates/4.5.stable/* ~/.local/share/godot/export_templates/4.5.stable/
          ls -la ~/.local/share/godot/export_templates/4.5.stable/ | head -10

      - name: Import assets
        run: godot --headless --path . --import || true

      - name: Export web build
        run: |
          mkdir -p build/web
          godot --headless --verbose --path . --export-release "Web" build/web/index.html

      - name: Add COOP/COEP headers file
        run: |
          cat > build/web/_headers << 'EOF'
          /*
            Cross-Origin-Embedder-Policy: require-corp
            Cross-Origin-Opener-Policy: same-origin
          EOF

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

**Note** : Pour que ce workflow fonctionne, vous devez activer GitHub Pages dans les paramètres du repository :
1. Aller sur `https://github.com/{user}/{repo}/settings/pages`
2. Dans **Source**, sélectionner **GitHub Actions**

## Étape 15 : Créer le preset d'export Web

Dans Godot, créer un preset d'export pour le Web :
1. Ouvrir **Project > Export...**
2. Cliquer **Add...** et sélectionner **Web**
3. Nommer le preset exactement **"Web"** (utilisé par les workflows)
4. Configurer les options selon vos besoins

Cela génère le fichier `export_presets.cfg` qui doit être commité.

## Commandes de test en développement local

### 1. Lancer le lobby server

```bash
godot --headless server_type=lobby environment=development --log_folder=./logs --executable_paths {{NOM_DU_JEU}}="chemin/vers/godot.exe" --paths {{NOM_DU_JEU}}="chemin/vers/projet"
```

### 2. Lancer des clients joueurs (ouvrir 2+ fenêtres)

```bash
godot --path . environment=development
```

## Résumé des fichiers créés

| Fichier | Description |
|---------|-------------|
| `config.gd` | Autoload pour parser les arguments CLI |
| `local_instance_manager.gd` | Gestionnaire de spawn des serveurs locaux |
| `game.gd` | Script principal orchestrant les 3 modes (PLAYER, SERVER, LOBBY) |
| `game.tscn` | Scène principale avec tous les composants multiplayer |
| `.gitignore` | Fichiers à ignorer par Git |
| `Dockerfile` | Image Docker du serveur de jeu headless |
| `Dockerfile.web` | Image Docker du client web (nginx) |
| `nginx.web.conf` | Config nginx avec headers COOP/COEP pour Godot 4 |
| `.dockerignore` | Fichiers à exclure de l'image Docker |
| `export_presets.cfg` | Presets d'export Godot (généré par l'éditeur) |
| `.github/workflows/docker-publish.yml` | CI/CD pour publier l'image serveur sur ghcr.io |
| `.github/workflows/deploy-web.yml` | CI/CD pour déployer le client web sur GitHub Pages |

## Arguments de configuration

### Arguments en ligne de commande

| Argument | Description | Défaut |
|----------|-------------|--------|
| `server_type` | Type d'instance : `PLAYER`, `room`, `lobby` | `PLAYER` |
| `environment` | `development` ou `production` | `production` |
| `lobby_url` | URL WebSocket du lobby (pour serveurs Docker) | Déduit de server_url |
| `port` | Port du serveur de jeu | Requis pour `room` |
| `code` | Code de la room (ex: ABC123) | Requis pour `room` |
| `log_folder` | Dossier des logs (pour lobby) | - |
| `paths` | Chemins des projets par jeu (pour lobby) | - |
| `executable_paths` | Chemins des exécutables par jeu (pour lobby) | - |

### Configuration via ProjectSettings (project.godot)

| Setting | Description | Défaut |
|---------|-------------|--------|
| `application/config/server_url` | URL du serveur en développement | `""` |
| `application/config/server_url_production` | URL de production (utilisé quand `OS.has_feature("web")`) | `{{URL_SERVEUR}}` |

**Note** : Les feature tag overrides (ex: `server_url.web`) ne fonctionnent pas à runtime à cause du bug Godot #101207. Le code utilise `OS.has_feature("web")` pour détecter l'environnement.

## Problèmes connus et solutions

### uid_cache.bin manquant en production

**Symptôme** : Erreurs "Unrecognized UID" au démarrage du serveur Docker.

**Cause** : La commande `--editor --quit-after 2` ne génère pas le fichier `uid_cache.bin`.

**Solution** : Utiliser `--import` dans le Dockerfile :
```dockerfile
RUN godot --headless --path /app --import || true
```

### Image Docker différente en local vs CI

**Symptôme** : L'image fonctionne en local mais pas quand elle est buildée par GitHub Actions.

**Cause** : Le dossier `.godot/` local est copié dans l'image, masquant les différences avec l'environnement CI.

**Solution** : Ajouter `.godot/` dans `.dockerignore` pour simuler l'environnement CI en local.

### Export templates non trouvés dans GitHub Actions

**Symptôme** : "No export template found at the expected path" dans le workflow deploy-web.

**Cause** : GitHub Actions utilise `/github/home/` comme HOME, mais les templates de `barichello/godot-ci` sont dans `/root/`.

**Solution** : Copier les templates vers le bon répertoire (voir étape "Setup export templates" dans le workflow).
