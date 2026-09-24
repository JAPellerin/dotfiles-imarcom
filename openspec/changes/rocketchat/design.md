## Context

Voir `proposal.md`. Le socle fournit `apt_install_deb_url`, `pkg_installed`, `install_system_file`, `manual_step`, et — **après `socle-github`** — `github_release_asset_url`.

Relevés du 23 sept 2026 :

| Fait | Mesure |
|---|---|
| Release 4.17.2 (22 sept) | `rocketchat-4.17.2-linux-amd64.deb`, AppImage, snap, rpm, tar.gz, `latest-linux.yml` |
| Contrôle du `.deb` | `Package: rocketchat`, `Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0` ; `/opt/Rocket.Chat/resources/app.asar`, `/usr/share/applications/rocketchat-desktop.desktop` |
| README, « Default servers » | `servers.json` = objet `{ "Nom": "URL" }` ; lu « only if no other servers have already been added » ; saute l'écran « Connect to server » ; **Linux** : `/home/<user>/.config/Rocket.Chat/` ou `/opt/Rocket.Chat/resources/` |
| Code du client, `src/servers/main.ts` (4.17.2 et `master`, relevé du 24 sept) | lus seulement si aucun serveur n'est enregistré ; `loadAppServers` lit `<resources>/servers.json` (`/opt/Rocket.Chat/resources/`) **sans y toucher** ; `loadUserServers` lit `~/.config/Rocket.Chat/servers.json` puis **le supprime** (`fs.promises.unlink`) ; les deux listes s'additionnent (rangées par URL) : à URL égale, le titre du fichier utilisateur l'emporte |
| Serveur | `https://rocketchat.imarcom.net` → 200 ; `/api/info` : version 8.6, client de bureau minimal 3.9.6 |

## Goals / Non-Goals

**Goals :** client installé, serveur de l'entreprise proposé d'office, rien de retéléchargé sur une relance.

**Non-Goals :** mode serveur unique, réglages imposés, connexion, mise à jour.

## Decisions

### D1. `.deb` par `github_release_asset_url`, motif `-linux-amd64\.deb$`
Même forme qu'`obsidian` D1 et D2 : `pkg_installed rocketchat` d'abord (aucun appel réseau si présent), sinon URL par le helper puis `apt_install_deb_url "$url" rocketchat`.

### D2. `servers.json` du paquet, copié par `install_system_file`
`config/rocketchat/servers.json` : `{ "Imarcom": "https://rocketchat.imarcom.net" }`, copié vers `/opt/Rocket.Chat/resources/servers.json` par `install_system_file` dans `module_configure`, donc après le paquet. Racine surchargeable pour les tests (`ROCKETCHAT_ROOT`, comme `CLAUDE_DESKTOP_ETC`).
Pas l'emplacement utilisateur `~/.config/Rocket.Chat/` (décision initiale, révisée le 24 sept 2026) : le client y supprime le fichier au premier lancement (`loadUserServers`), un lien disparaîtrait et `module_check` ne serait plus jamais satisfait. Le fichier du paquet est relu sans être supprimé : l'état reste constatable. Le fichier n'est déclaré par aucun paquet : `dpkg` ne le retire pas lors d'une mise à jour (à confirmer en VM, tâche 2.1). Si l'utilisateur retire tous ses serveurs, le client repropose celui de l'entreprise.
Limite documentée : le fichier n'agit que si aucun serveur n'a encore été ajouté. Sur un poste neuf, c'est le cas.

### D3. Étape de connexion dans `module_install`
Comme `obsidian` D3 : déclarée après un `apt_install_deb_url` réussi quand le paquet était absent ; aucune variable transmise à `module_configure` (sous-shells du runner). `module_configure` fait la copie de D2.

### D4. `module_check`
`pkg_installed rocketchat && cmp -s "$DOTFILES_DIR/config/rocketchat/servers.json" "$ROCKETCHAT_ROOT/opt/Rocket.Chat/resources/servers.json"` — comme `claude-desktop`, lu sans `sudo` ni réseau.

### D5. Tests
`tests/test-rocketchat.sh` : `HOME` et racine (`ROCKETCHAT_ROOT`) isolés, doublures `dpkg-query`, `github_release_asset_url`, `apt_install_deb_url` (comme `obsidian`) et `run_sudo` (comme `claude-desktop`) ; fonctions appelées **par `module_call`**. Cas : première application (motif `-linux-amd64\.deb$`, paquet `rocketchat`, fichier copié identique au dépôt, étape de connexion) ; `config/rocketchat/servers.json` est un JSON valide qui désigne `https://rocketchat.imarcom.net` (`jq`) ; déjà installé → aucun appel au helper ; fichier retiré ou différent → `module_check` à faire, `module_configure` le réécrit ; fichier utilisateur `~/.config/Rocket.Chat/servers.json` supprimé par le client → toujours « déjà fait » ; écriture système en échec → `module_configure` échoue ; recherche ou installation en échec → aucune étape ; `module_check` sur chaque condition.

## Risks / Trade-offs

- [Un serveur a déjà été ajouté à la main] → `servers.json` est ignoré par le client (documenté) ; sans conséquence.
- [Une mise à jour du paquet retire le fichier, ou le paquet livre un jour son propre `servers.json`] → `module_check` repasse « à faire », une relance recopie le fichier ; la survie à une mise à jour est vérifiée en VM (2.1).
- [L'adresse du serveur change] → une ligne dans `config/rocketchat/servers.json`.
- [Adresse dans un dépôt public] → adresse publique, joignable depuis Internet ; aucun identifiant n'est versionné.

## Migration Plan

Aucune. Retour arrière : `apt remove rocketchat`, `sudo rm /opt/Rocket.Chat/resources/servers.json`.
