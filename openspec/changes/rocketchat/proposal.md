## Why

Rocket.Chat est la messagerie de l'entreprise (`rocketchat.imarcom.net`, serveur 8.6). Sur un poste neuf, le client de bureau doit être installé et **déjà pointé sur le serveur de l'entreprise**, pour que l'utilisateur n'ait plus qu'à se connecter.

Rocket.Chat ne publie pas de dépôt apt pour son client : il distribue sur les releases GitHub de `RocketChat/Rocket.Chat.Electron` un `.deb` amd64 (4.17.2, 22 sept 2026), avec AppImage, snap et rpm. Le `.deb` passe par les helpers du socle, comme `obsidian`.

## What Changes

- **Module `rocketchat`** (`modules/61-rocketchat.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - URL du `.deb` le plus récent par `github_release_asset_url RocketChat/Rocket.Chat.Electron '-linux-amd64\.deb$'` (change `socle-github`), installation par `apt_install_deb_url` (paquet `rocketchat`) ;
  - **serveur pré-configuré** : `config/rocketchat/servers.json` (`{"Imarcom": "https://rocketchat.imarcom.net"}`) **copié** vers `/opt/Rocket.Chat/resources/servers.json` par `install_system_file` — fichier par défaut du paquet, mécanisme et emplacement documentés par Rocket.Chat pour Linux (« Default servers ») ; l'emplacement utilisateur `~/.config/Rocket.Chat/` est écarté : le client y supprime le fichier après l'avoir lu (relevé du 24 sept 2026) : au premier lancement, l'écran « Connect to server » est sauté et le client ouvre directement la page de connexion de ce serveur ;
  - **profil AppArmor** (ajouté le 24 sept 2026, après le test en VM) : sans lui, Ubuntu 26.04 refuse au client les espaces de noms utilisateur et il plante au lancement ; le paquet n'installe pas le sien (et le vise mal) : `config/rocketchat/apparmor-profile` copié vers `/etc/apparmor.d/rocketchat-desktop` et chargé par `apparmor_parser -r` ;
  - étape manuelle à la première installation : se connecter à Rocket.Chat.

Décision de l'utilisateur (23 sept 2026) : **pré-configurer le serveur** `rocketchat.imarcom.net`. L'adresse est versionnée dans le dépôt public : c'est une adresse publique (le serveur répond sur Internet), pas un secret.

**Prérequis : le change `socle-github`.**

Hors périmètre :

- **Mode serveur unique** (`isAddNewServersEnabled: false`) et autres réglages imposés (`overridden-settings.json`) : l'utilisateur peut ajouter d'autres serveurs.
- **Connexion** au compte : faite dans l'application.
- **Mise à jour** : le client la propose lui-même ; le module ne réinstalle pas un paquet présent.

## Capabilities

### New Capabilities
- `module-rocketchat` : le module `rocketchat` — client de bureau depuis son `.deb` officiel le plus récent, serveur de l'entreprise pré-configuré, connexion en étape manuelle.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/61-rocketchat.sh`, `config/rocketchat/servers.json`, `config/rocketchat/apparmor-profile`, `tests/test-rocketchat.sh`.
- Écritures système (avec `sudo`) : paquet `rocketchat` (`/opt/Rocket.Chat`, `rocketchat-desktop.desktop`) ; `/opt/Rocket.Chat/resources/servers.json` (copie du dépôt, déclarée par aucun paquet) ; `/etc/apparmor.d/rocketchat-desktop` (copie du dépôt), chargé dans le noyau.
- Réseau : `api.github.com`, `github.com` (≈ 100 Mio). Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL ; validation en VM.
- Docs : `ROADMAP.md` (`rocketchat` fait).
