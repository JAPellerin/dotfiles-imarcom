## Context

Voir `proposal.md`. Le socle fournit `apt_install_deb_url`, `pkg_installed`, `link_config` / `config_linked`, `manual_step`, et — **après `socle-github`** — `github_release_asset_url`.

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Release 4.17.2 (22 sept) | `rocketchat-4.17.2-linux-amd64.deb`, AppImage, snap, rpm, tar.gz, `latest-linux.yml` |
| Contrôle du `.deb` | `Package: rocketchat`, `Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0` ; `/opt/Rocket.Chat/resources/app.asar`, `/usr/share/applications/rocketchat-desktop.desktop` |
| README, « Default servers » | `servers.json` = objet `{ "Nom": "URL" }` ; lu « only if no other servers have already been added » ; saute l'écran « Connect to server » ; **Linux** : `/home/<user>/.config/Rocket.Chat/` ou `/opt/Rocket.Chat/resources/` |
| Serveur | `https://rocketchat.imarcom.net` → 200 ; `/api/info` : version 8.6, client de bureau minimal 3.9.6 |

## Goals / Non-Goals

**Goals :** client installé, serveur de l'entreprise proposé d'office, rien de retéléchargé sur une relance.

**Non-Goals :** mode serveur unique, réglages imposés, connexion, mise à jour.

## Decisions

### D1. `.deb` par `github_release_asset_url`, motif `-linux-amd64\.deb$`
Même forme qu'`obsidian` D1 et D2 : `pkg_installed rocketchat` d'abord (aucun appel réseau si présent), sinon URL par le helper puis `apt_install_deb_url "$url" rocketchat`.

### D2. `servers.json` utilisateur, lié par `link_config`
`config/rocketchat/servers.json` : `{ "Imarcom": "https://rocketchat.imarcom.net" }`, lié vers `~/.config/Rocket.Chat/servers.json`. L'emplacement utilisateur plutôt que `/opt/Rocket.Chat/resources/` : pas de `sudo`, et un fichier sous `/opt` appartient au paquet — une mise à jour du paquet pourrait le retirer. Le client ne réécrit pas ce fichier (il est lu, les serveurs ajoutés vivent dans ses propres préférences) : un lien convient, et `config_linked` sert de critère.
Limite documentée : le fichier n'agit que si aucun serveur n'a encore été ajouté. Sur un poste neuf, c'est le cas.

### D3. Étape de connexion dans `module_install`
Comme `obsidian` D3 : déclarée après un `apt_install_deb_url` réussi quand le paquet était absent ; aucune variable transmise à `module_configure` (sous-shells du runner). `module_configure` fait le `link_config` de D2.

### D4. `module_check`
`pkg_installed rocketchat && config_linked config/rocketchat/servers.json ~/.config/Rocket.Chat/servers.json`.

### D5. Tests
`tests/test-rocketchat.sh` : `HOME` isolé, doublures `dpkg-query`, `github_release_asset_url`, `apt_install_deb_url` (comme `obsidian`) ; fonctions appelées **par `module_call`**. Cas : première application (motif `-linux-amd64\.deb$`, paquet `rocketchat`, lien créé, étape de connexion) ; `config/rocketchat/servers.json` est un JSON valide qui désigne `https://rocketchat.imarcom.net` (`jq`) ; déjà installé → aucun appel au helper ; lien retiré → `module_check` à faire, `module_configure` le recrée ; fichier existant écrit à la main → sauvegardé en `.bak` ; recherche ou installation en échec → aucune étape ; `module_check` sur chaque condition.

## Risks / Trade-offs

- [Un serveur a déjà été ajouté à la main] → `servers.json` est ignoré par le client (documenté) ; sans conséquence.
- [L'adresse du serveur change] → une ligne dans `config/rocketchat/servers.json`.
- [Adresse dans un dépôt public] → adresse publique, joignable depuis Internet ; aucun identifiant n'est versionné.

## Migration Plan

Aucune. Retour arrière : `apt remove rocketchat`, retrait du lien `~/.config/Rocket.Chat/servers.json`.
