# Arguments de configuration

## Arguments en ligne de commande

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

## Configuration via ProjectSettings (project.godot)

| Setting | Description | Défaut |
|---------|-------------|--------|
| `application/config/server_url` | URL du serveur en développement | `""` |
| `application/config/server_url_production` | URL de production (utilisé quand `OS.has_feature("web")`) | Configuré par l'utilisateur |

**Note** : Les feature tag overrides (ex: `server_url.web`) ne fonctionnent pas à runtime à cause du bug Godot #101207. Le code utilise `OS.has_feature("web")` pour détecter l'environnement.

## Exemples de commandes

### Lancer le lobby server (développement local)

```bash
godot --headless server_type=lobby environment=development \
    --log_folder=./logs \
    --executable_paths mon-jeu="/chemin/vers/godot.exe" \
    --paths mon-jeu="/chemin/vers/projet"
```

### Lancer un serveur de jeu manuellement

```bash
godot --headless server_type=room environment=development \
    code=ABC123 port=18000
```

### Lancer un client joueur

```bash
godot --path . environment=development
```
