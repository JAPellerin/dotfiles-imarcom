## Context

Voir `proposal.md`. Le socle fournit `apt_add_repo`, `apt_install`, `pkg_installed`, `install_system_file`, `manual_step`.

Relevés du 23 sept 2026 (page « Spotify for Linux » et dépôt) :

| Fait | Mesure |
|---|---|
| Doc Spotify | `curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \| sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg` ; `deb https://repository.spotify.com stable non-free` ; `apt-get install spotify-client` |
| Clé | `pubkey_5384CE82BA52C83A.asc` → 200 (armurée) |
| Dépôt | `https://repository.spotify.com/dists/stable/Release` → 200 ; `spotify-client` 1:1.2.95.453 (amd64) |

Relevés du 24 sept 2026 (contre-vérification) :

| Fait | Mesure |
|---|---|
| Clé | empreinte `E1096BCBFF6D418796DE78515384CE82BA52C83A`, la même qui signe `InRelease` ; **expire le 2027-02-14** |
| `postinst` de `spotify-client` 1:1.2.95.453 | copie `apt-keys/*.gpg` du paquet dans `/etc/apt/trusted.gpg.d/` s'ils n'y sont pas ; puis, si aucun **`.list`** (ni `sources.list`) ne cite `repository.spotify.com stable non-free` **et** que `/etc/apt/sources.list.d/spotify.list` n'existe pas, écrit ce fichier (`deb https://repository.spotify.com stable non-free`). Les `.sources` ne sont pas lus. Désactivation prévue par le script : « `sudo touch /etc/apt/sources.list.d/spotify.list` » |
| Dépendances dans resolute | `libasound2`, `libgtk-3-0`, `libglib2.0-0`, `libatk-bridge2.0-0` fournis par les paquets `*t64` (`Provides`) ; `libayatana-appindicator3-1` présent. Recommandé `libavcodec61 \| 60 \| 58` : resolute n'a que `libavcodec62` |

## Goals / Non-Goals

**Goals :** dépôt déclaré par le socle et par lui seul, paquet installé, connexion signalée.

**Non-Goals :** réglages, compte, snap.

## Decisions

### D1. `apt_add_repo spotify <clé> https://repository.spotify.com stable non-free`
Clé armurée → `/etc/apt/keyrings/spotify.asc`, `spotify.sources` en deb822 : la forme du socle, plutôt que `trusted.gpg.d` et un `.list` comme dans la doc — même dépôt, même clé, mais une clé liée à son seul dépôt (`Signed-By`) au lieu d'un trousseau de confiance global. Le nom du fichier de clé de Spotify porte son identifiant (`pubkey_5384CE82BA52C83A.asc`) : Spotify le change quand il renouvelle sa clé. C'est une constante du module ; un téléchargement en échec est nommé par `apt_add_repo` (« Clé introuvable »).

### D2. Étape de connexion dans `module_install`
Déclarée après un `apt_install` réussi quand `spotify-client` était absent au début de `module_install` — jamais par une variable passée à `module_configure` (sous-shells du runner). `module_configure` ne fait rien. `module_check` = `pkg_installed spotify-client` **et** `spotify.list` identique au fichier versionné (D3).

### D3. Le paquet déclare son propre dépôt : `spotify.list` sans entrée, posé avant
Le `postinst` écrit `/etc/apt/sources.list.d/spotify.list` quand il ne trouve le dépôt dans aucun `.list` — il ignore le `spotify.sources` du socle. Deux déclarations du même dépôt, l'une avec `Signed-By`, l'autre sans : apt refuse la liste des sources (« Conflicting values set for option Signed-By ») et **tout** `apt update` échoue. Même piège que Chrome (`/etc/default/google-chrome`) et Claude Desktop (`/etc/default/claude-desktop`), mais sans fichier de réglage : la seule désactivation prévue par Spotify est l'existence de `spotify.list`.

- `config/spotify/spotify.list`, versionné : commentaires seuls (rôle du fichier, renvoi au `postinst`), aucune ligne `deb`. apt accepte un `.list` sans entrée ; le `postinst` voit le fichier et n'écrit rien.
- Posé par `install_system_file` **avant** `apt_install`, à chaque `module_install` (idempotent). Il fait partie de `module_check` : relu à chaque mise à jour du paquet, il doit rester en place.
- Alternative écartée : déclarer le dépôt dans `spotify.list` au lieu du `.sources` du socle — ce serait sortir de `apt_add_repo` pour un seul module, et le `.list` n'aurait pas de `Signed-By`.

**Clé dans `trusted.gpg.d`** : le `postinst` y copie les clés embarquées dans le paquet, sans moyen de l'en empêcher, et recommence à chaque mise à jour. Les retirer serait défait à la mise à jour suivante : on l'accepte. Le bénéfice de D1 (clé liée au seul dépôt) n'est donc que partiel ; le dépôt reste déclaré par le socle.

### D4. Tests
`tests/test-spotify.sh` : doublures `dpkg-query`, `run_sudo` (simule `apt-get install` et la copie `install` vers un `/etc` du dossier temporaire, via `SPOTIFY_ETC`), `apt_add_repo` (compte) ; fonctions appelées **par `module_call`**. Cas : première application (`spotify.list` posé avec le contenu versionné, sans ligne `deb`, **avant** l'installation ; dépôt `spotify` avec la clé et la suite `stable non-free`, déclaré avant l'installation ; paquet `spotify-client` ; étape de connexion) ; déjà installé → aucune étape, rien de réécrit ; `spotify.list` supprimé ou modifié → à faire, rétabli ; installation en échec → aucune étape ; `module_check` sur le paquet.

## Risks / Trade-offs

- [Spotify renouvelle sa clé] → nouvelle URL à reporter dans la constante ; l'échec est nommé.
- [Dépôt en retard ou retiré de l'architecture] → hors de notre contrôle ; échec apt nommé.
- [Clé expirée le 2027-02-14] → `apt update` signale le dépôt Spotify (EXPKEYSIG) tant que la clé n'est pas renouvelée. Si Spotify prolonge la clé sous le même nom de fichier, `apt_add_repo` la remplace à la relance du module — mais `module_check` ne regarde pas la clé, le module « déjà fait » ne sera pas relancé de lui-même. Question commune à tous les modules `apt_add_repo`, à traiter au socle, pas ici.
- [Une mise à jour du paquet change son `postinst`] → le mécanisme `spotify.list` n'est pas documenté hors du script ; si Spotify le change, le doublon reviendrait. Relevé à refaire quand un `apt update` signale un conflit sur `repository.spotify.com`.
- [`libavcodec` recommandé absent de resolute] → les recommandations ne sont pas satisfaites ; sans effet sur l'écoute en streaming (la lecture de fichiers locaux pourrait en pâtir). Hors périmètre.

## Migration Plan

Aucune. Retour arrière : `apt remove spotify-client`, retrait de `spotify.sources`, `spotify.list` et `spotify.asc` (et des clés Spotify de `/etc/apt/trusted.gpg.d/`).
