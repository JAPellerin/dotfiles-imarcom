## Context

Voir `proposal.md`. Le socle fournit `apt_add_repo`, `apt_install`, `pkg_installed`, `manual_step`.

Relevés du 23 sept 2026 (page « Spotify for Linux » et dépôt) :

| Fait | Mesure |
|---|---|
| Doc Spotify | `curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \| sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg` ; `deb https://repository.spotify.com stable non-free` ; `apt-get install spotify-client` |
| Clé | `pubkey_5384CE82BA52C83A.asc` → 200 (armurée) |
| Dépôt | `https://repository.spotify.com/dists/stable/Release` → 200 ; `spotify-client` 1:1.2.95.453 (amd64) |

## Goals / Non-Goals

**Goals :** dépôt déclaré par le socle, paquet installé, connexion signalée.

**Non-Goals :** réglages, compte, snap.

## Decisions

### D1. `apt_add_repo spotify <clé> https://repository.spotify.com stable non-free`
Clé armurée → `/etc/apt/keyrings/spotify.asc`, `spotify.sources` en deb822 : la forme du socle, plutôt que `trusted.gpg.d` et un `.list` comme dans la doc — même dépôt, même clé, mais une clé liée à son seul dépôt (`Signed-By`) au lieu d'un trousseau de confiance global. Le nom du fichier de clé de Spotify porte son identifiant (`pubkey_5384CE82BA52C83A.asc`) : Spotify le change quand il renouvelle sa clé. C'est une constante du module ; un téléchargement en échec est nommé par `apt_add_repo` (« Clé introuvable »).

### D2. Étape de connexion dans `module_install`
Déclarée après un `apt_install` réussi quand `spotify-client` était absent au début de `module_install` — jamais par une variable passée à `module_configure` (sous-shells du runner). `module_configure` ne fait rien. `module_check` = `pkg_installed spotify-client`.

### D3. Paquet qui déclarerait son propre dépôt
Aucun mécanisme de ce genre n'est documenté pour `spotify-client` (contrairement à Chrome, VS Code ou Claude Desktop). Constaté en VM (tâche 2.1) : un seul fichier de dépôt Spotify après installation ; sinon, design corrigé avant l'archive.

### D4. Tests
`tests/test-spotify.sh` : doublures `dpkg-query`, `run_sudo` (simule `apt-get install`), `apt_add_repo` (compte) ; fonctions appelées **par `module_call`**. Cas : première application (dépôt `spotify` avec la clé et la suite `stable non-free`, déclaré avant l'installation ; paquet `spotify-client` ; étape de connexion) ; déjà installé → aucune étape ; installation en échec → aucune étape ; `module_check` sur le paquet.

## Risks / Trade-offs

- [Spotify renouvelle sa clé] → nouvelle URL à reporter dans la constante ; l'échec est nommé.
- [Dépôt en retard ou retiré de l'architecture] → hors de notre contrôle ; échec apt nommé.

## Migration Plan

Aucune. Retour arrière : `apt remove spotify-client`, retrait de `spotify.sources` et `spotify.asc`.
