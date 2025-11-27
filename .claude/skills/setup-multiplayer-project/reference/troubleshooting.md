# Troubleshooting

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

### Feature tag overrides ne fonctionnent pas

**Symptôme** : Les settings avec suffixes comme `config/server_url.web` ne sont pas appliqués à runtime.

**Cause** : Bug Godot #101207 - les feature tag overrides dans ProjectSettings ne fonctionnent qu'à l'export, pas à runtime.

**Solution** : Utiliser deux settings séparés (`server_url` et `server_url_production`) et `OS.has_feature("web")` dans le code pour détecter l'environnement.

### Connexion WebSocket échoue en production

**Symptôme** : Le client web ne peut pas se connecter au serveur.

**Causes possibles** :
1. Headers COOP/COEP manquants
2. Certificat SSL invalide
3. URL incorrecte

**Solutions** :
1. Vérifier que nginx.web.conf contient les headers requis
2. Vérifier la configuration SSL du reverse proxy
3. Vérifier que `server_url_production` est correctement configuré dans project.godot

### Joueurs ne spawn pas

**Symptôme** : Les joueurs rejoignent la room mais leur personnage n'apparaît pas.

**Causes possibles** :
1. `player_scene_path` incorrect dans PlayerSpawner
2. Scène joueur non ajoutée au MultiplayerSpawner
3. Problème d'autorité multiplayer

**Solutions** :
1. Vérifier le chemin dans game.tscn
2. S'assurer que la scène est bien enregistrée comme spawnable
3. Vérifier que `set_multiplayer_authority()` est appelé correctement
