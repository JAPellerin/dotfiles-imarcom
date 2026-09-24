## Why

Spotify fait partie des applications de bureau de l'utilisateur. La ROADMAP le disait « facultatif » : **décision de l'utilisateur (23 sept 2026), c'est un module normal** — précoché dans le menu tant qu'il n'est pas fait, à décocher si on n'en veut pas. Aucun changement au runner.

Spotify publie un **dépôt apt officiel** (`repository.spotify.com`, `spotify-client` 1:1.2.95, relevé le 23 sept 2026) : c'est la voie de CLAUDE.md (dépôt de l'éditeur, clé dans `/etc/apt/keyrings/`), sans snap ni flatpak.

## What Changes

- **Module `spotify`** (`modules/63-spotify.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - `/etc/apt/sources.list.d/spotify.list` posé **avant le paquet**, sans aucune entrée (commentaire seul) : sinon le `postinst` de `spotify-client` y écrit le dépôt, en double du `.sources` du socle, et le conflit `Signed-By` casse `apt update` (constaté le 24 sept 2026 dans le paquet 1:1.2.95) ;
  - dépôt apt de Spotify par `apt_add_repo` (clé publiée par Spotify, suite `stable`, composant `non-free`) ;
  - paquet `spotify-client` par `apt_install` ;
  - étape manuelle à la première installation : se connecter à Spotify.

Hors périmètre : réglages de l'application, compte.

## Capabilities

### New Capabilities
- `module-spotify` : le module `spotify` — client Spotify depuis le dépôt apt de l'éditeur, connexion en étape manuelle.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/63-spotify.sh`, `config/spotify/spotify.list` et `tests/test-spotify.sh`.
- Écritures système (avec `sudo`) : `/etc/apt/sources.list.d/spotify.list` (sans entrée), `/etc/apt/keyrings/spotify.asc`, `/etc/apt/sources.list.d/spotify.sources`, paquet `spotify-client` — dont le `postinst` copie aussi ses clés dans `/etc/apt/trusted.gpg.d/` (sans moyen de l'en empêcher, design D3).
- Réseau : `download.spotify.com` (clé), `repository.spotify.com`. Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL ; validation en VM.
- Docs : `ROADMAP.md` (`spotify` fait, « facultatif » retiré).
