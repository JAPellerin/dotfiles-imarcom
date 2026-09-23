## Context

Voir `proposal.md`. Le socle fournit `run`, `log_*`, `apt_install_deb_url <url> <paquet>` (ne fait rien si le paquet est installé, contrôle `dpkg-deb --info`). `jq` est installé par `base`.

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| `GET /repos/obsidianmd/obsidian-releases/releases?per_page=10` | v1.13.8 (latest) : seulement `Obsidian-1.13.8.apk` ; v1.13.7 : `obsidian_1.13.7_amd64.deb`, AppImage, `.tar.gz` |
| `GET /repos/RocketChat/Rocket.Chat.Electron/releases/latest` | 4.17.2 : `rocketchat-4.17.2-linux-amd64.deb` (+ AppImage, snap, rpm, tar.gz) |
| Ordre de la liste des releases | de la plus récente à la plus ancienne (date de création) |
| API sans jeton | 60 requêtes par heure et par adresse IP |

## Goals / Non-Goals

**Goals :** trouver l'URL du dernier `.deb` réellement publié, en un appel, sans jeton ; échec lisible.

**Non-Goals :** télécharger (c'est `apt_install_deb_url`) ; choisir une version précise ; authentification.

## Decisions

### D1. Une requête sur la liste des releases, filtrée par jq
`curl -fsSL --retry 2 "https://api.github.com/repos/<dépôt>/releases?per_page=20"` puis `jq -r --arg re "<motif>" '[.[] | select((.draft or .prerelease) | not) | .assets[] | select(.name | test($re)) | .browser_download_url][0] // empty'`. `/releases/latest` est écarté : il désigne la dernière release, pas la dernière qui contient le fichier (cas d'Obsidian). 20 releases couvrent largement l'écart entre deux `.deb`.
La réponse passe par un fichier temporaire, pas par un tube `curl | jq` : un échec de `curl` (réseau, limite de débit, dépôt inconnu) doit se distinguer d'une liste sans fichier correspondant, et nommer la bonne cause.

### D2. Sortie : l'URL seule sur stdout, tout le reste au journal ou sur stderr
Le helper s'emploie en substitution : `url=$(github_release_asset_url obsidianmd/obsidian-releases '_amd64\.deb$') || return 1`. Rien d'autre ne sort sur stdout ; les messages passent par `log_*` (stderr et journal). Le `curl` n'est pas lancé par `run` (sa sortie est le document JSON lui-même) : il écrit dans le temporaire, et son échec est journalisé à la main.

### D3. Motif : expression régulière étendue sur le nom du fichier
Chaque module passe un motif ancré (`_amd64\.deb$`, `-linux-amd64\.deb$`) ; l'architecture est dans le motif, pas déduite par le helper — les deux projets n'ont pas la même convention de nommage.

### D4. Fichier `lib/github.sh`
Un fichier par thème (comme `lib/fonts.sh`, `lib/groups.sh`). Chargé par `setup.sh` après `lib/apt.sh`. URL de l'API surchargeable (`GITHUB_API_URL`) pour les tests, qui servent des réponses JSON en `file://`.

### D5. Tests
`tests/test-github.sh` : réponses JSON fabriquées, servies en `file://` par `GITHUB_API_URL`. Cas : dernière release complète ; dernière release sans le fichier (forme d'Obsidian) → précédente ; préversion et brouillon plus récents ignorés ; aucun fichier → échec nommant dépôt et motif, stdout vide ; réponse absente (`curl` en échec) → échec nommant le dépôt ; JSON invalide → échec ; stdout ne contient que l'URL.

## Risks / Trade-offs

- [Limite de 60 requêtes par heure] → un appel par module et par installation ; `module_check` ne l'appelle jamais.
- [Un éditeur change le nom de ses fichiers] → le motif ne correspond plus, échec nommé, motif à corriger dans le module.
- [Pas de somme de contrôle] → même niveau de confiance que le téléchargement manuel depuis la page de l'éditeur ; `apt_install_deb_url` rejette un fichier qui n'est pas un paquet Debian.

## Migration Plan

Aucune : nouveau fichier.
