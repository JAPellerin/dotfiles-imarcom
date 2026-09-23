## Why

Obsidian est l'outil de notes de l'utilisateur — le suivi de ce projet y vit (« Dotfiles - suivi du projet »). Sur un poste neuf, il doit être là sans passer par la page de téléchargement.

Obsidian ne publie **aucun dépôt apt** : il distribue sur les releases GitHub de `obsidianmd/obsidian-releases` un `.deb` (amd64), une AppImage et une archive. **Décision de l'utilisateur (23 sept 2026) : le `.deb`**, installé par le helper du socle `apt_install_deb_url` — le paquet s'intègre au système (lanceur, icône, dépendances résolues par apt, désinstallation par `apt remove`), sans helper AppImage à écrire.

## What Changes

- **Module `obsidian`** (`modules/60-obsidian.sh`, groupe `apps`, dépend de `base`, **session graphique requise**) :
  - URL du `.deb` le plus récent trouvée par `github_release_asset_url obsidianmd/obsidian-releases '_amd64\.deb$'` (change `socle-github`) — la release « latest » d'Obsidian peut ne contenir qu'un `.apk` Android (v1.13.8, relevé le 23 sept 2026), le helper remonte à la dernière release qui a le `.deb` ;
  - installation par `apt_install_deb_url` (paquet `obsidian`) ;
  - étape manuelle à la première installation : ouvrir Obsidian et ouvrir (ou synchroniser) son coffre de notes.

**Prérequis : le change `socle-github`.**

Hors périmètre :

- **Mise à jour** : Obsidian se met à jour de lui-même dans l'application (il télécharge sa nouvelle version dans son dossier de configuration) ; le `.deb` installé reste celui de l'installation, ce que l'application gère. Le module ne réinstalle pas un paquet déjà présent.
- **Coffre, Obsidian Sync, extensions** : choix et compte de l'utilisateur, faits dans l'application.
- **AppImage** : écartée au profit du `.deb` (décision ci-dessus) ; aucun helper AppImage n'est nécessaire à la vague 3.
- **arm64** : Obsidian ne publie pas de `.deb` arm64 ; le laptop est amd64.

## Capabilities

### New Capabilities
- `module-obsidian` : le module `obsidian` — `.deb` officiel le plus récent depuis les releases GitHub, installé par le socle, ouverture du coffre en étape manuelle.

### Modified Capabilities
_Aucune._

## Impact

- Nouveaux `modules/60-obsidian.sh` et `tests/test-obsidian.sh`.
- Écritures système (avec `sudo`) : paquet `obsidian` (dans `/opt/Obsidian`, lanceur dans `/usr/share/applications`).
- Réseau : `api.github.com`, `github.com` (≈ 100 Mio). Les tests restent hors ligne.
- **Module graphique** : sauté dans la WSL ; validation en VM.
- Docs : `ROADMAP.md` (`obsidian` fait).
