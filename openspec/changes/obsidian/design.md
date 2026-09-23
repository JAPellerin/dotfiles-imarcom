## Context

Voir `proposal.md`. Le socle fournit `apt_install_deb_url <url> <paquet>` (vague 0), `pkg_installed`, `manual_step`, et — **après `socle-github`** — `github_release_asset_url <dépôt> <motif>`.

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Releases `obsidianmd/obsidian-releases` | v1.13.8 (latest, 21 août) : `Obsidian-1.13.8.apk` seul ; v1.13.7 (12 août) et antérieures : `obsidian_<v>_amd64.deb`, AppImage (x86_64, arm64), `.tar.gz` |
| Contrôle du `.deb` v1.13.7 | `Package: obsidian`, `Architecture: amd64`, `Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0`, `Recommends: libappindicator3-1`, ~338 Mio installés |
| Dépôt apt Obsidian | aucun |

## Goals / Non-Goals

**Goals :** le `.deb` le plus récent, installé par le socle ; rien de retéléchargé sur une relance.

**Non-Goals :** mise à jour (l'application s'en charge), coffre, Sync, extensions, AppImage.

## Decisions

### D1. URL par `github_release_asset_url`, motif `_amd64\.deb$`
`url=$(github_release_asset_url obsidianmd/obsidian-releases '_amd64\.deb$') || return 1`, puis `apt_install_deb_url "$url" obsidian`. Le helper remonte à la dernière release qui contient le `.deb` (v1.13.7 aujourd'hui, pas l'`.apk` de v1.13.8).

### D2. Aucun appel réseau si le paquet est là
`module_install` commence par `pkg_installed obsidian` : si vrai, `log_ok` et retour, sans interroger GitHub (`apt_install_deb_url` ferait le même constat, mais seulement après la recherche de l'URL). `module_check` = `pkg_installed obsidian`.

### D3. Étape manuelle dans `module_install`
Déclarée après un `apt_install_deb_url` réussi, quand le paquet était absent au début de `module_install` : « Ouvrir Obsidian (menu des applications) et ouvrir ou synchroniser son coffre de notes. ». **Pas de variable transmise à `module_configure`** : le runner lance les deux fonctions dans deux sous-shells (`module_call`, `lib/module.sh`) — défaut rencontré sur `vscode` le 23 sept 2026. `module_configure` ne fait rien (`return 0`).

### D4. Mise à jour : laissée à l'application
Obsidian télécharge ses mises à jour dans son dossier de configuration et les applique au démarrage ; le `.deb` n'a pas à suivre. Réinstaller un `.deb` plus récent à chaque relance du module violerait « rien de retéléchargé » et n'apporterait rien.

### D5. Tests
`tests/test-obsidian.sh` : doublures `dpkg-query` (fichier), `github_release_asset_url` (imprime une URL ou échoue selon un marqueur, compte ses appels), `apt_install_deb_url` (journalise, ajoute `obsidian` aux paquets installés, ou échoue selon un marqueur). Fonctions appelées **par `module_call`**, chacune dans son sous-shell, comme le runner. Cas : première application (motif `_amd64\.deb$` passé au helper, URL passée à `apt_install_deb_url` avec le paquet `obsidian`, étape manuelle au fichier des étapes) ; déjà installé → aucun appel au helper ni au téléchargement ; recherche d'URL en échec → module en échec, aucun téléchargement, aucune étape ; installation en échec → aucune étape ; `module_check` sur le paquet.

## Risks / Trade-offs

- [L'éditeur renomme ses `.deb`] → le motif ne correspond plus, échec nommé ; motif à corriger.
- [Le `.deb` installé vieillit] → l'application se met à jour elle-même (D4) ; un poste neuf reçoit toujours le dernier `.deb`.

## Migration Plan

Aucune. Retour arrière : `apt remove obsidian` (le coffre et la configuration de l'utilisateur ne sont pas touchés).
